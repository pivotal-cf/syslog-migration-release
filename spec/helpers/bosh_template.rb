require 'yaml'
require 'bosh/template/property_helper'
require 'bosh/template/renderer'

module BoshTemplate
  extend Bosh::Template::PropertyHelper

  def self.render(template_path, job_name, manifest, links)
    context = self.renderer_context(job_name, manifest, links)
    renderer = Bosh::Template::Renderer.new(context: context.to_json)
    renderer.render(template_path)
  end

  def self.renderer_context(job_name, manifest, links)
    context = self.merge_job_spec_defaults(job_name, manifest)
    context['job'] = { 'name' => job_name }
    context['index'] = 13
    context['id'] = 'instance-id'
    context['links'] = links
    context
  end

  def self.merge_job_spec_defaults(job_name, manifest)
    jobs = manifest.fetch('instance_groups').first.fetch('jobs')
    job = jobs.find { |job| job.fetch('name') == job_name }
    job_properties = job.fetch('properties', {})

    job_spec = YAML.load_file("jobs/#{job_name}/spec")
    job_spec_properties = job_spec.fetch('properties')

    merged_properties = {}
    job_spec_properties.each_pair do |name, definition|
      self.copy_property(merged_properties, job_properties, name, definition['default'])
    end

    manifest.merge({'properties' => merged_properties})
  end
end
