# Perform all the necessary preparation to execute the page-rendering
# libraries.

require_relative 'path'
require_relative 'data'

APPNAME = 'HeapChart'

config = AppData::Config.load

DATA_STORE = case config['database']
             in 'sqlite'
               Sequel.sqlite(config.dig('sqlite', 'path'))
             in 'postgres'
               options = config.fetch('postgres')
               options["password"] = File.read(options["password"]).strip

               Sequel.postgres(options["database"], **options)
             end

AppData.table_init DATA_STORE

# Due to Sequel's magic, model classes can't be defined until after the DB is
# connected.  The real definitions are still logically grouped with the schema
# definitions in the data library.

class User < Sequel::Model
  class_exec &AppData::Model::USER
end

class Library < Sequel::Model
  class_exec &AppData::Model::LIBRARY
end

class Floor < Sequel::Model
  class_exec &AppData::Model::FLOOR
end

NaturallyCompare = AppData::NaturallyCompare
Session = AppData::Session

configure do
  enable :sessions
  set :sessions, key: Session::COOKIE
  #set :sessions, secure: settings.production?
  set :session_secret, File.read('data/session_secret').strip
  set :bind, '0.0.0.0'
  set :port, 22000
end

# Preprocessing for every request.
before do
  # Never allow insecure communication in production.
  if settings.production? && !request.secure?
    #redirect request.url.sub(/^http/i, 'https'), 301
  end

  @user = Session.user?(session, User)
  if @user.nil?
    # Handle possibility of deleted users still being logged in.
    Session.log_out(session)

    unless Path.public? request.path_info
      redirect Path::LOGIN, 303
    end
  end

  # Autogenerate a default page title.
  title_parts = request.path_info.split('/').drop(1).map(&:capitalize)
  unless title_parts.empty?
    @title = title_parts.join ' '
  end
end

# methods available in view renderers.
helpers do
  # Sometimes it's nice to know that you weren't called by some malicious
  # external site.
  def assert_local_referrer
    unless URI(request.referrer).host == request.host
      redirect request.referrer, 303
    end
  end

  # Pages like /login are the rare kind inappropriate for logged in users.
  def assert_logged_out
    if @user
      redirect Path::DASHBOARD, 303
    end
  end

  # Handlers that have their objects pre-loaded for them will only receive a
  # nil object if they were asked to create a new object (i.e. the path
  # included Path::CREATION_ID).  Invalid real IDs will be caught and handled
  # by the pre-loader.  See also #path_id_loader_for.
  def path_demands_creation_of(object); object.nil?; end

  # Set ERB as our templating engine.
  alias_method :view, :erb

  # Everything in HTML is a string.  When it comes to request parameters, it's
  # more ergonomic for us to have Rubyish nils and symbols.
  # Request parameters also may include extraneous keys, so we filter by keys
  # we explicitly know to be object attributes.
  def extract_attributes(params, *attr_keys)
    params.map { |key,value|
      value = value.strip
      value = nil if value == ""
      [ key.to_sym, value ]
    }.to_h.slice(*attr_keys)
  end
end

# Produce a function (an anonymous lambda) that can be used as a #before
# handler to pre-load the relevant object named by the ID string in the
# request path.
# e.g. @library from Library[id_from_path]
#
# The function handles both real ids and the magic Path::CREATION_ID that
# leaves the @variable unassigned.
# Handlers that don't create new objects and therefore must have a valid object
# given to them must check if the relevant instance variable, e.g. @library, is
# nil.  The helper #path_demands_creation_of is provided for this purpose.
def path_id_loader_for(name)
  name = name.to_sym
  # Constant definitions in the global scope are attached to Object.
  model_class = Object.const_get(name.capitalize)
  instance_variable_name = :"@#{name.downcase}"

  ->(id_string_from_path) {
    # ID strings from paths must be all digits or the magic creation ID.
    unless /^([0-9]+|#{Path::CREATION_ID})$/i =~ id_string_from_path
      halt 500, "invalid #{name} id"
    end
    # If we got a real ID, then use the appropriate model class to retrieve the
    # object with that ID.  Otherwise, we can leave the @variable unset since
    # Ruby implicitly treats unset @variables as nil.
    if id_string_from_path.downcase != Path::CREATION_ID
      # Get object
      true_id = Integer(id_string_from_path, 10)
      object = model_class[true_id]
      # Verify the explicit ID actually names a real object.
      if object.nil?
        halt 404, "there is no #{name} with ID #{id_string_from_path.inspect}"
      end

      # Hand the valid object off to the request handler!
      instance_variable_set(
        instance_variable_name,
        object,
      )
    end
  }
end

LOAD_LIBRARY_FROM_PATH = path_id_loader_for :library
LOAD_FLOOR_FROM_PATH = path_id_loader_for :floor
