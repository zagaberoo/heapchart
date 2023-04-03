#
# Dashboard
#

get Path::DASHBOARD do
  view :dashboard
end

#
# Login
#

before Path::LOGIN do
  assert_logged_out
end

get Path::LOGIN do
  view :login
end

post Path::LOGIN do
  username, password = params[:username] || "", params[:password] || ""
  if username.empty? || password.empty?
    halt 500, "username and password are required"
  end

  user = User[name: username]
  if user.nil? || user.password != password
    halt 500, "access denied."
  end

  Session.log_in(session, user)
  redirect Path::DASHBOARD, 303
end

#
# Logout
#

get Path::LOGOUT do
  # Only links on the site itself may cause the user to log out.
  assert_local_referrer

  Session.log_out(session)
  redirect Path::LOGIN, 303
end

#
# Signup
#

before Path::SIGNUP do
  assert_logged_out
end

get Path::SIGNUP do
  view :signup
end

post Path::SIGNUP do
  # Validate Username

  username = params[:username] || ""
  if username.empty?
    halt 500, "username is required"
  end

  minimum = Data::Session::USERNAME_MIN
  if username.length < minimum
    halt 500, "username must have at least #{minimum} characters"
  end

  users = DATA_STORE[:users]
  if users[name: username]
    halt 500, "username #{username.inspect} unavailable"
  end

  # Validate Password

  if params[:password] != params[:redundant_password]
    halt 500, "passwords do not match"
  end

  password = params[:password] || ""
  if password.empty?
    halt 500, "password is required"
  end

  minimum = Data::Session::PASSWORD_MIN
  if password.length < minimum
    halt 500, "password must have at least #{minimum} characters"
  end

  # Add User!

  users.insert(
    name: username,
    secret_hash: BCrypt::Password.create(password),
  )

  redirect Path::LOGIN, 303
end
