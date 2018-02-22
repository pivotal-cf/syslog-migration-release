require 'bosh/template/test'

RSpec.describe 'syslog_forwarder pre-start' do
  before(:all) do
    release_path = File.join(File.dirname(__FILE__), '..')
    release = Bosh::Template::Test::ReleaseDir.new(release_path)
    job = release.job('syslog_forwarder')
    @template = job.template('bin/pre-start')
  end

  it 'does not delete any files' do
    pre_start_script = @template.render({})
    expect(pre_start_script).not_to include('rm -f')
  end

  it 'deletes files in /etc/rsyslog.d' do
    properties = job_properties(cleanup_conf_files: [
      '00-default.conf',
      '01-custom.conf'
    ])
    pre_start_script = @template.render(properties)
    expect(pre_start_script).to include('rm -f /etc/rsyslog.d/00-default.conf')
    expect(pre_start_script).to include('rm -f /etc/rsyslog.d/01-custom.conf')
  end

  it 'does not delete files outside /etc/rsyslog.d' do
    properties = job_properties(cleanup_conf_files: [
      '../../var/log/syslog',
      '../../var/vcap/store/my_data.yml',
      '00-default.conf'
    ])
    pre_start_script = @template.render(properties)
    expect(pre_start_script).to include('rm -f /etc/rsyslog.d/00-default.conf')
    expect(pre_start_script).not_to include('/var/log/syslog')
    expect(pre_start_script).not_to include('/var/vcap/store/my_data.yml')
  end

  def job_properties(cleanup_conf_files:)
    {
      'syslog' => {
        'migration' => {
          'cleanup_conf_files' => cleanup_conf_files
        }
      }
    }
  end
end
