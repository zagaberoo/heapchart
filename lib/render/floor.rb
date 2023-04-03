#
# All Floors
#

get Path::Floor::LIST do
  @floors = Floor.all.sort(&NaturallyCompare[:floors])
  view :floors
end

#
# Floor Details
#

before Path::Floor::VIEW, &LOAD_FLOOR_FROM_PATH

get Path::Floor::VIEW do
  if path_demands_creation_of @floor
    redirect Path::Floor::CREATE, 301
  end

  view :floors_view
end

#
# Edit Floor Details
#

before Path::Floor::EDIT, &LOAD_FLOOR_FROM_PATH

get Path::Floor::EDIT do
  view :floors_edit
end

post Path::Floor::EDIT do
  attrs = extract_attributes(params, :name, :directions, :order)

  if attrs[:name].nil?
    halt 500, "name is required"
  end

  if attrs[:order] && !(/^[0-9]+$/ =~ attrs[:order])
    halt 500, "invalid floor order #{attrs[:order].inspect}"
  end

  if @floor.nil?
    DATA_STORE[:floors].insert(**attrs)
  else
    @floor.update(**attrs)
  end

  redirect Path::Floor::LIST, 303
end

#
# Delete Floor
#

before Path::Floor::DELETE, &LOAD_FLOOR_FROM_PATH

get Path::Floor::DELETE do
  if path_demands_creation_of @floor
    halt 200, "Yes."
  end

  view :floors_delete
end

post Path::Floor::DELETE do
  if path_demands_creation_of @floor
    halt 500, "cannot delete nonexistent floor"
  end

  if params[:confirmation] != "confirmed!"
    # back to the confirmation page via GET
    redirect Path::Floor::DELETE[@floor.id], 303
  end

  @floor.delete
  redirect Path::Floor::LIST, 303
end

#
# Reassign Floor to Library
#

before Path::Floor::ASSIGN, &LOAD_FLOOR_FROM_PATH

get Path::Floor::ASSIGN do
  if path_demands_creation_of @floor
    halt 500, "cannot reassign nonexistent floor"
  end

  @libraries = Library.all.sort(&NaturallyCompare[:names])
  view :floors_assign
end

post Path::Floor::ASSIGN do
  if path_demands_creation_of @floor
    halt 500, "cannot reassign nonexistent floor"
  end

  library_id = params[:library]
  unless /^[0-9]+$/ =~ library_id
    halt 500, "cannot assign to invalid library id #{library_id.inspect}"
  end

  @floor.update(library_id: Integer(library_id, 10))

  redirect Path::Floor::LIST, 303
end

#
# Clear Floor Library Assignment
#

before Path::Floor::UNASSIGN, &LOAD_FLOOR_FROM_PATH

get Path::Floor::UNASSIGN do
  # If we're going to mutate on GET (because unassigning doesn't deserve a
  # confirmation page to POST from), then make sure this isn't some off-site
  # hotlink trying to mutate our data.
  assert_local_referrer

  if path_demands_creation_of @floor
    halt 500, "cannot unassign nonexistent floor"
  end

  @floor.update(library_id: nil)
  redirect request.referrer, 303
end
