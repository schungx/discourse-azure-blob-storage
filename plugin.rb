# name: discourse-azure-blob-storage
# about: Azure Blob storage
# version: 0.0.3
# authors: Maja Komel
# url: https://github.com/discourse/discourse-azure-blob-storage

require "file_store/base_store"

# GEMS
gem 'faraday_middleware', '1.0.0', {require: true}
gem 'connection_pool', '2.2.5', {require: false}
gem 'net-http-persistent', '4.0.1', require: true, require_name: "net/http/persistent"
gem 'azure-storage-common', '2.0.2', {require: false}
gem 'azure-storage-blob', '2.0.1', {require: false}

require 'azure/storage/blob'

enabled_site_setting :azure_blob_storage_enabled

require_relative "lib/azure_blob_store"

after_initialize do
  class ::Faraday::Adapter::NetHttpPersistent
    def self.new(*)
      self.load_error = nil

      super
    end
  end

  SiteSetting::Upload.class_eval do
    class << self
      alias_method :core_s3_cdn_url, :s3_cdn_url
      alias_method :core_enable_s3_uploads, :enable_s3_uploads
      alias_method :core_absolute_base_url, :absolute_base_url
      alias_method :core_s3_base_url, :s3_base_url
    end

    def self.s3_cdn_url
      if SiteSetting.azure_blob_storage_enabled
        SiteSetting.azure_cdn_url
      else
        core_s3_cdn_url
      end
    end

    def self.enable_s3_uploads
      return true if SiteSetting.azure_blob_storage_enabled
      core_enable_s3_uploads
    end

    def self.s3_base_url
      return "//#{SiteSetting.azure_blob_storage_account_name}.blob.core.windows.net" if SiteSetting.azure_blob_storage_enabled
      core_s3_base_url
    end

    def self.absolute_base_url
      return "//#{SiteSetting.azure_blob_storage_account_name}.blob.core.windows.net" if SiteSetting.azure_blob_storage_enabled
      core_absolute_base_url
    end
  end

  Discourse.module_eval do
    class << self
      alias_method :core_store, :store
    end
    def self.store
      if SiteSetting.azure_blob_storage_enabled
        @azure_blob_loaded ||= require './plugins/discourse-azure-blob-storage/lib/azure_blob_store'
        FileStore::AzureStore.new
      else
        core_store
      end
    end
  end

end
