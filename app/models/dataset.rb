require "datastreams/workflow_rdf_datastream"
require "datastreams/dataset_rdf_datastream"
require "datastreams/relations_rdf_datastream"
require "datastreams/dataset_admin_rdf_datastream"
require "dataset_agreement"
#require "person"
require "rdf"
require "fileutils"

class Dataset < ActiveFedora::Base
  include Hydra::AccessControls::Permissions
  include Sufia::GenericFile::AccessibleAttributes
  #include Sufia::GenericFile::WebForm
  include Sufia::Noid
  include Hydra::ModelMethods

  attr_accessible *(DatasetRdfDatastream.fields + RelationsRdfDatastream.fields + [:permissions, :permissions_attributes, :workflows, :workflows_attributes] + DatasetAdminRdfDatastream.fields)
  
  before_create :initialize_submission_workflow

  before_save :remove_blank_assertions

  has_metadata :name => "descMetadata", :type => DatasetRdfDatastream
  has_metadata :name => "workflowMetadata", :type => WorkflowRdfDatastream
  has_metadata :name => "relationsMetadata", :type => RelationsRdfDatastream
  has_metadata :name => "adminMetadata", :type => DatasetAdminRdfDatastream

  belongs_to :hasRelatedAgreement, :property=>:has_agreement, :class_name=>"DatasetAgreement"

  has_attributes :workflows, :workflows_attributes, datastream: :workflowMetadata, multiple: true
  has_attributes *DatasetRdfDatastream.fields, datastream: :descMetadata, multiple: true
  has_attributes *RelationsRdfDatastream.fields, datastream: :relationsMetadata, multiple: true
  has_attributes *DatasetAdminRdfDatastream.fields, datastream: :adminMetadata, multiple: true

  #has_and_belongs_to_many :authors, :property=> :has_author, :class_name=>"Person"
  #has_and_belongs_to_many :contributors, :property=> :has_contributor, :class_name=>"Person"

  def to_solr(solr_doc={}, opts={})
    super(solr_doc, opts)
    solr_doc[Solrizer.solr_name('label')] = self.label
    return solr_doc
  end

  def apply_permissions(depositor)
    prop_ds = self.datastreams["workflowMetadata"]
    rights_ds = self.datastreams["rightsMetadata"]
    depositor_id = depositor.respond_to?(:user_key) ? depositor.user_key : depositor
    if prop_ds
      prop_ds.depositor = depositor_id unless prop_ds.nil?
    end
    rights_ds.permissions({:person=>depositor_id}, 'edit') unless rights_ds.nil?
    rights_ds.permissions({:group=>"reviewer"}, 'edit') unless rights_ds.nil?
    return true
  end
  
  def to_jq_upload(title, size, pid, dsid)
    return {
      "name" => title, #self.title,
      "size" => size, #self.file_size,
      "url" => "/datasets/#{pid}/#{dsid}", #"/dataset/#{noid}",
      "thumbnail_url" => thumbnail_url(title, '48'),#self.pid,
      "delete_url" => "deleteme", # generic_file_path(:id => id),
      "delete_type" => "DELETE"
    }
  end

  def save_file(file, pid)
    name =  file.original_filename
    name = File.basename(name) 
    if pid.include?('sufia:')
      pid = pid.gsub('sufia:', '')
    end
    directory = "/data/%s" % pid
    FileUtils::mkdir_p(directory) 
    # create the file path
    path = File.join(directory, name)
    # write the file
    File.open(path, "wb") { |f| f.write(file.read) }
    path
  end

  def delete_file(file_location)
    File.delete(file_location) if File.exist?(file_location)
  end

  def delete_dir(pid)
    if pid.include?('sufia:')
      pid = pid.gsub('sufia:', '')
    end
    directory = "/data/%s" % pid
    FileUtils.rm_rf(directory) if File.exist?(directory)
  end

  def create_external_datastream(dsid, url, file_name, file_size)
    set_title_and_label(file_name, :only_if_blank=>true )
    mime_types = MIME::Types.of(file_name)
    mime_type = mime_types.empty? ? "application/octet-stream" : mime_types.first.content_type
    attrs = {:dsLabel => dsid, :controlGroup => "E", :dsLocation=>url, :mimeType=>mime_type, :dsid=>dsid, :size=>file_size}
    ds = create_datastream(ActiveFedora::Datastream, dsid, attrs)
    ds
  end

  private
  
  def initialize_submission_workflow
    if self.workflows.empty?  
      wf = self.workflows.build(identifier:"MediatedSubmission")
      wf.entries.build(status:"Draft", date:Time.now.to_s)
    end
  end

  def remove_blank_assertions
    DatasetRdfDatastream.fields.each do |key|
      if !["temporal", "dateCollected", "spatial"].include?(key)
        self[key] = nil if self[key] == ['']
      end
    end
  end

  def self.find_or_create(pid)
    begin
      Dataset.find(pid)
    rescue ActiveFedora::ObjectNotFoundError
      Dataset.create({pid: pid})
    end
  end

  def thumbnail_url(filename, size)
    icon = "fileIcons/default-icon-#{size}x#{size}.png"
    begin
      mt = MIME::Types.of(filename)
      extensions = mt[0].extensions
    rescue
      extensions = []
    end
    for ext in extensions
      if Rails.application.assets.find_asset("fileIcons/#{ext}-icon-#{size}x#{size}.png")
        icon = "fileIcons/#{ext}-icon-#{size}x#{size}.png"
      end
    end
    icon
  end

end
