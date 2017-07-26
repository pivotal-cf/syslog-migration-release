require 'helpers/bosh_template'

RSpec.describe 'syslog_forwarder rsyslog.conf' do
  let(:template_path) { 'jobs/syslog_forwarder/templates/rsyslog.conf.erb' }
  let(:job_name) { 'syslog_forwarder' }
  let(:minimum_manifest) do
    <<~MINIMUM_MANIFEST
    instance_groups:
    - name: syslog_forwarder
      jobs:
      - name: syslog_forwarder
    MINIMUM_MANIFEST
  end
  let(:links) do
    {
      "syslog_storer" => {
        "instances" => [
          { "address" => "my.syslog_storer.bosh" }
        ],
        "properties" => {
          "syslog" => {
            "port" => "some-syslog-storer-port",
            "transport" => "relp"
          }
        }
      }
    }
  end

  it 'allows rsyslog to be configured with the RFC5424 format' do
    manifest = generate_manifest_with_message_format(minimum_manifest, nil)
    actual_template = BoshTemplate.render(template_path, job_name, manifest, links)

    expected_message_format = Fixtures.read('rsyslog_with_rfc5424_format.conf')
    expect(actual_template).to include expected_message_format
  end

  it 'allows rsyslog to be configured with the job_index format' do
    manifest = generate_manifest_with_message_format(minimum_manifest, 'job_index')
    actual_template = BoshTemplate.render(template_path, job_name, manifest, links)

    expected_message_format = Fixtures.read('rsyslog_with_job_index_format.conf')
    expect(actual_template).to include expected_message_format
  end

  it 'allows rsyslog to be configured with the job_index_id format' do
    manifest = generate_manifest_with_message_format(minimum_manifest, 'job_index_id')
    actual_template = BoshTemplate.render(template_path, job_name, manifest, links)

    expected_message_format = Fixtures.read('rsyslog_with_job_index_id_format.conf')
    expect(actual_template).to include expected_message_format
  end

  it 'prevents rsyslog from being configured with unknown formats' do
    manifest = generate_manifest_with_message_format(minimum_manifest, 'crazy-format')
    expect {
      BoshTemplate.render(template_path, job_name, manifest, links)
    }.to raise_error(RuntimeError, "unknown syslog.migration.message_format: crazy-format")
  end
end

def generate_manifest(raw_manifest)
  manifest = YAML.load(raw_manifest)
  yield(manifest) if block_given?
  manifest
end

def generate_manifest_with_message_format(raw_manifest, message_format)
  generate_manifest(raw_manifest) do |manifest|
    manifest['instance_groups'][0]['jobs'][0]['properties'] = {
      'syslog' => {
        'migration' => {
          'message_format' => message_format
        }
      }
    }
  end
end
