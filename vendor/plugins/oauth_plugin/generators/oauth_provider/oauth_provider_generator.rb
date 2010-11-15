class OauthProviderGenerator < Rails::Generator::Base
  default_options :skip_migration => false
  attr_reader   :class_path,
                :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_name,
                :controller_singular_name,
                :controller_plural_name
  alias_method  :controller_file_name,  :controller_singular_name

  def initialize(runtime_args, runtime_options = {})
    super

    @controller_name = args.shift || 'oauth'
    @controller_singular_name = 'oauth'
    @controller_plural_name = 'oauth'
    @controller_file_name = 'oauth'
    @controller_class_name="Oauth"
    @class_path=''
    @controller_class_path=''
  end

  def manifest
    record do |m|
      
      # Check for class naming collisions.
      # Check for class naming collisions.
      m.class_collisions controller_class_path,       "#{controller_class_name}Controller", # Oauth Controller
                                                      "#{controller_class_name}Helper"
      m.class_collisions class_path,                  "ClientApplication","OauthNonce","RequestToken","AccessToken","OauthToken"

      # Controller, helper, views, and test directories.
      m.directory File.join('app/models', class_path)
      m.directory File.join('app/controllers', controller_class_path)
      m.directory File.join('app/helpers', controller_class_path)
      m.directory File.join('app/views', controller_class_path, controller_file_name)
      m.directory File.join('spec')
      m.directory File.join('spec/models')
      m.directory File.join('spec/fixtures', class_path)
      m.directory File.join('spec/controllers', controller_class_path)

      m.template 'client_application.rb',File.join('app/models',"client_application.rb")
      m.template 'oauth_token.rb',    File.join('app/models',"oauth_token.rb")
      m.template 'request_token.rb',  File.join('app/models',"request_token.rb")
      m.template 'access_token.rb',   File.join('app/models',"access_token.rb")
      m.template 'oauth_nonce.rb',    File.join('app/models',"oauth_nonce.rb")

      m.template 'client_application_spec.rb',File.join('spec/models',"client_application_spec.rb")
      m.template 'oauth_token_spec.rb',    File.join('spec/models',"oauth_token_spec.rb")
      m.template 'oauth_nonce_spec.rb',    File.join('spec/models',"oauth_nonce_spec.rb")


      m.template 'client_applications.yml',File.join('spec/fixtures',"client_applications.yml")
      m.template 'oauth_tokens.yml',    File.join('spec/fixtures',"oauth_tokens.yml")
      m.template 'oauth_nonces.yml',    File.join('spec/fixtures',"oauth_nonces.yml")
      
      m.template 'controller.rb',File.join('app/controllers',controller_class_path,"#{controller_file_name}_controller.rb")
      m.template 'helper.rb',File.join('app/helpers',controller_class_path,"#{controller_file_name}_helper.rb")
      m.template 'controller_spec.rb',File.join('spec/controllers',controller_class_path,"#{controller_file_name}_controller_spec.rb")

      m.template 'new.rhtml',  File.join('app/views', controller_class_path, controller_file_name, "new.rhtml")
      m.template 'index.rhtml',  File.join('app/views', controller_class_path, controller_file_name, "index.rhtml")
      m.template 'show.rhtml',  File.join('app/views', controller_class_path, controller_file_name, "show.rhtml")
      m.template 'authorize.rhtml',  File.join('app/views', controller_class_path, controller_file_name, "authorize.rhtml")
      m.template 'authorize_success.rhtml',  File.join('app/views', controller_class_path, controller_file_name, "authorize_success.rhtml")
      m.template 'authorize_failure.rhtml',  File.join('app/views', controller_class_path, controller_file_name, "authorize_failure.rhtml")
      m.template '_form.rhtml',  File.join('app/views', controller_class_path, controller_file_name, "_form.rhtml")

      unless options[:skip_migration]
        m.migration_template 'migration.rb', 'db/migrate', :assigns => {
          :migration_name => "CreateOauthTables"
        }, :migration_file_name => "create_oauth_tables"
      end
    end
  end

  protected
    def banner
      "Usage: #{$0} #{spec.name}"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--skip-migration", 
             "Don't generate a migration file") { |v| options[:skip_migration] = v }
    end
end
