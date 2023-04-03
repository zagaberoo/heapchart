# Single-location definitions for all the paths that make up the site.

module Path
  LOGIN = '/login'
  LOGOUT = '/logout'
  SIGNUP = '/signup'
  DASHBOARD = '/'

  # Marks where in a path an object's ID number will appear.  Used both by app
  # code, and as part of native Sinatra URL routing which will capture the
  # actual ID value in a client's request path for handlers to use.
  ID_VAR = ':id'
  # Magic value that can appear in paths in place of a numeric ID to indicate
  # that the operation should create a new object instead of loading one by ID.
  CREATION_ID = 'new'

  # Allow paths with variable IDs to self-modify (via a copy) for tidiness.
  # e.g.  Path::Floor::VIEW[@floor.id]
  module IdSettable
    # Add the ID-setting method to an individual string object's singleton
    # class.  Affects no other string objects.
    def id_settable(string)
      fail unless string.match ID_VAR
      string.define_singleton_method :[], &SETTER
      string
    end

    # Because this lambda is attached as a method body to strings, self will
    # always be a string.
    SETTER = ->(id) { self.gsub(ID_VAR, id.to_s) }
  end

  module Floor
    extend IdSettable

    LIST = '/floors'
    VIEW = id_settable "/floor/#{ID_VAR}"
    ASSIGN = id_settable "/floor/#{ID_VAR}/assign"
    UNASSIGN = id_settable ASSIGN.sub("assign", "unassign")
    DELETE = id_settable "/floor/#{ID_VAR}/delete"
    EDIT = id_settable "/floor/#{ID_VAR}/edit"
    CREATE = EDIT[CREATION_ID]
  end

  module Library
    extend IdSettable

    LIST = '/libraries'
    VIEW = id_settable "/library/#{ID_VAR}"
    DELETE = id_settable "/library/#{ID_VAR}/delete"
    EDIT = id_settable "/library/#{ID_VAR}/edit"
    CREATE = EDIT[CREATION_ID]
    REORGANIZE = id_settable "/library/#{ID_VAR}/reorganize"
  end
  
  PUBLICS = [ LOGIN, SIGNUP ]

  def self.public?(path)
    PUBLICS.include? path
  end
end
