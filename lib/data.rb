# Schemas and algorithms related to the handling of application data.
#
# - database and model schemas
# - natural sort data comparators
# - user session data configuration
# - configuration from TOML file


module AppData
  # These lambdas can be given to Sequel to treat as database schema
  # definitions.
  TABLE_SPEC = {
    users: -> {
      primary_key :id

      column(
        :name, String,
        null: false,
        unique: true,
      )
      column :secret_hash, String
      column :when_created, DateTime, default: Sequel::CURRENT_TIMESTAMP
    },

    libraries: -> {
      primary_key :id
      
      column(
        :name, String,
        null: false,
        unique: true,
      )
    },

    floors: -> {
      primary_key :id
      foreign_key(
         :library_id, :libraries,
         deferrable: true,
         on_delete: :set_null,
         on_update: :cascade,
      )

      column(
        :name, String,
        null: false,
        unique: true,
      )
      column :directions, String, text: true
      column :order, Integer
    },
  }

  def self.table_init(data_store)
    TABLE_SPEC.each do |name,spec|
      if !data_store.table_exists? name
        data_store.create_table name, &spec
      end
    end
  end

  module Model
    # Named objects will automatically be represented in strings by their
    # names.
    module NamedObject
      def to_s; name; end
    end

    # Sequel magic means model classes must be declared after db connection,
    # but I still want the definitions to live here with the db schema since
    # they're so closely related.
    # So, lambdas to exec against the actual definitions in init it is!

    USER = -> {
      include NamedObject

      def password
        @password ||= BCrypt::Password.new(secret_hash)
      end
    }

    LIBRARY = -> {
      include NamedObject

      one_to_many :floors
    }

    FLOOR = -> {
      include NamedObject

      many_to_one :library
    }
  end

  # Handle natural comparison, where whole numbers of any length within strings
  # are considered to be individual integer 'characters'.
  module NaturallyCompare
    # Allow methods to be accessed quickly to be passed as the block for #sort.
    def self.[](method_name)
      method(method_name)
    end

    def self.names(left, right)
      strings(left.name, right.name)
    end

    def self.floors(left, right)
      # Compare three criteria of descending importance:
      # - the names of the floors' libraries
      # - the ordering numbers of the floors
      # - the floors' names

      # The strings comparator handles nils for us.
      result = strings(left.library&.name,
                       right.library&.name)
      return result if result.nonzero?

      # We want unordered items to sink, so treat nil as infinity.
      result = (left.order || Float::INFINITY
               ) <=> (
                right.order || Float::INFINITY)
      return result if result.nonzero?

      names(left, right)
    end

    def self.strings(left, right)
      # Shorter strings rank higher, but we want nil to sink to the bottom, so
      # we can't just replace nils with "".  There's no nice Float::INFINITY
      # equivalent for strings, either.
      case [left, right]
      in [nil, String]
        1
      in [String, nil]
        -1
      in [String, String] | [nil, nil]
        left ||= ""
        right ||= ""
        TOKENIZER[left].zip(TOKENIZER[right]).each do |left,right|
          result = CMP[left, right]
          return result if result.nonzero?
        end
        # zip combines the two sequences nicely, but if left is empty it won't
        # do any comparisons, which could fail to recognize right potentially
        # being nonempty.
        left.length <=> right.length
      end
    end

    # Compare two "characters" of the type produced by TOKENIZER.
    CMP = ->(left, right) {
      case [left, right]
      in [nil, nil]
        0
      # shorter strings come first
      in [nil, Integer] | [nil, String]
        -1
      in [Integer, nil] | [String, nil]
        1
      # numbers come before letters
      in [Integer, String]
        -1
      in [String, Integer]
        1
      # numbers are easy
      in [Integer, Integer]
        left <=> right
      # strings are hard
      in [String, String]
        if left.casecmp?(right)
          # If the strings are equivalent other than case, then compare them
          # normally so capitals come first.  'A' comes before 'a'.
          left <=> right
        else
          # If the strings are completely different, compare them caselessly so
          # 'Z' doesn't come before 'a'.  Phew!
          left.casecmp(right)
        end
      end
    }
    private_constant :CMP

    # Break a string up into "characters", where a "character" is either a
    # non-digit one-character string, or an individual integer of any length.
    TOKENIZER = ->(string) {
      string.scan(/[^0-9]|[0-9]+/).map {
        if /[0-9]+/ =~ _1
          _1.to_i
        else
          _1
        end
      }
    }
    private_constant :TOKENIZER
  end

  # Configuration related to a user's session state, which is stored in an
  # obfuscated, tamper-evident cookie.
  module Session
    COOKIE = 'SESSION'
    USER_ID = :uid
    PASSWORD_MIN = 8
    USERNAME_MIN = 3

    def self.user?(session, user_model)
      user_model[session[USER_ID]]
    end

    def self.log_in(session, user)
      session[USER_ID] = user.id
    end

    def self.log_out(session)
      session.delete USER_ID
    end
  end

  module Config
    PATH = "data/config.toml"

    def self.load
      TOML::Parser.new(File.read(PATH)).parsed
    end
  end
end
