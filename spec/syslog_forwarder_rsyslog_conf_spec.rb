require 'bosh/template/test'
require 'yaml'

RSpec.describe 'syslog_forwarder rsyslog.conf' do
  before(:all) do
    release_path = File.join(File.dirname(__FILE__), '..')
    release = Bosh::Template::Test::ReleaseDir.new(release_path)
    job = release.job('syslog_forwarder')
    @template = job.template('config/rsyslog.conf')
    @links = [
      Bosh::Template::Test::Link.new(
        name: 'syslog_storer',
        instances: [
          Bosh::Template::Test::LinkInstance.new(address: 'my.syslog_storer.bosh')
        ],
        properties: {
          'syslog' => {
            'port' => 'some-syslog-storer-port',
            'transport' => 'relp'
          }
        }
      )
    ]
  end

  it 'defaults to rsyslog being configured with the RFC5424 format' do
    rsyslog_conf = @template.render({}, consumes: @links)

    expected_message_format = Fixtures.read('rsyslog_with_rfc5424_format.conf')
    expect(rsyslog_conf).to include expected_message_format
  end

  it 'allows rsyslog to be configured with the RFC5424 format' do
    properties = job_properties(message_format: 'rfc5424')
    rsyslog_conf = @template.render(properties, consumes: @links)

    expected_message_format = Fixtures.read('rsyslog_with_rfc5424_format.conf')
    expect(rsyslog_conf).to include expected_message_format
  end

  it 'allows rsyslog to be configured with the job_index format' do
    properties = job_properties(message_format: 'job_index')
    rsyslog_conf = @template.render(properties, consumes: @links)

    expected_message_format = Fixtures.read('rsyslog_with_job_index_format.conf')
    expect(rsyslog_conf).to include expected_message_format
  end

  it 'allows rsyslog to be configured with the job_index_id format' do
    properties = job_properties(message_format: 'job_index_id')
    rsyslog_conf = @template.render(properties, consumes: @links)

    expected_message_format = Fixtures.read('rsyslog_with_job_index_id_format.conf')
    expect(rsyslog_conf).to include expected_message_format
  end

  it 'prevents rsyslog from being configured with unknown formats' do
    properties = job_properties(message_format: 'crazy-format')

    expect {
      @template.render(properties, consumes: @links)
    }.to raise_error(RuntimeError, "unknown syslog.migration.message_format: crazy-format")
  end

  def job_properties(message_format:)
    {
      'syslog' => {
        'migration' => {
          'message_format' => message_format
        }
      }
    }
  end
end
