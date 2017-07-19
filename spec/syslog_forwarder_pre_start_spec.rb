require 'json'
require 'yaml'
require 'helpers/bosh_template'

RSpec.describe 'syslog_forwarder pre-start' do
  TEMPLATE_PATH = 'jobs/syslog_forwarder/templates/pre-start.erb'
  JOB_NAME = 'syslog_forwarder'
  MINIMUM_MANIFEST = <<~MINIMUM_MANIFEST
  instance_groups:
  - name: syslog_forwarder
    jobs:
    - name: syslog_forwarder
  MINIMUM_MANIFEST
  NO_LINKS = {}

  it 'does not delete any files' do
    manifest = generate_manifest_cleanup_conf_files
    actual_template = BoshTemplate.render(TEMPLATE_PATH, JOB_NAME, manifest, NO_LINKS)
    expect(actual_template).not_to include('rm -f /etc/rsyslog.d')
  end

  it 'deletes files in /etc/rsyslog.d' do
    manifest = generate_manifest_cleanup_conf_files('00-default.conf', '01-custom.conf')
    actual_template = BoshTemplate.render(TEMPLATE_PATH, JOB_NAME, manifest, NO_LINKS)
    expect(actual_template).to include('rm -f /etc/rsyslog.d/00-default.conf')
    expect(actual_template).to include('rm -f /etc/rsyslog.d/01-custom.conf')
  end

  it 'does not delete files outside /etc/rsyslog.d' do
    manifest = generate_manifest_cleanup_conf_files('../../var/log/syslog',
      '../../var/vcap/store/my_data.yml', '00-default.conf')
    actual_template = BoshTemplate.render(TEMPLATE_PATH, JOB_NAME, manifest, NO_LINKS)
    expect(actual_template).to include('rm -f /etc/rsyslog.d/00-default.conf')
    expect(actual_template).not_to include('/var/log/syslog')
    expect(actual_template).not_to include('/var/vcap/store/my_data.yml')
  end
end

def generate_manifest(minimum_manifest)
  manifest = YAML.load(minimum_manifest)
  yield(manifest) if block_given?
  manifest
end

def generate_manifest_cleanup_conf_files(*filenames)
  generate_manifest(MINIMUM_MANIFEST) do |manifest|
    manifest['instance_groups'][0]['jobs'][0]['properties'] = {
      'syslog' => {
        'migration' => {
          'cleanup_conf_files' => filenames
        }
      }
    }
  end
end
