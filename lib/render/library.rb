#
# All Libraries
#

get Path::Library::LIST do
  @libraries = Library.all.sort(&NaturallyCompare[:names])
  view :libraries
end

#
# Library Details
#

before Path::Library::VIEW, &LOAD_LIBRARY_FROM_PATH

get Path::Library::VIEW do
  if path_demands_creation_of @library
    redirect Path::Library::NEW, 301
  end

  @floors = @library.floors.sort(&NaturallyCompare[:floors])
  view :libraries_view
end

#
# Edit Library Details
#

before Path::Library::EDIT, &LOAD_LIBRARY_FROM_PATH

get Path::Library::EDIT do
  view :libraries_edit
end

post Path::Library::EDIT do
  name = params[:name] || ""
  if name.empty?
    halt 500, "name is required"
  end

  if @library.nil?
    DATA_STORE[:libraries].insert(name: name)
  else
    @library.update(name: name)
  end

  redirect Path::Library::LIST, 303
end

#
# Delete Library
#

before Path::Library::DELETE, &LOAD_LIBRARY_FROM_PATH

get Path::Library::DELETE do
  if path_demands_creation_of @library
    halt 200, "Yes."
  end

  view :libraries_delete
end

post Path::Library::DELETE do
  if path_demands_creation_of @library
    halt 500, "cannot delete nonexistent library"
  end

  if params[:confirmation] != "confirmed!"
    # back to the confirmation page via GET
    redirect Path::Library::DELETE[@library.id], 303
  end

  DATA_STORE.transaction do
    if params[:cascade] == "on"
      DATA_STORE[:floors].where(library_id: @library.id).delete
    end
    @library.delete
  end

  redirect Path::Library::LIST, 303
end

#
# Reorder Library Floors
#

before Path::Library::REORGANIZE, &LOAD_LIBRARY_FROM_PATH

get Path::Library::REORGANIZE do
  if path_demands_creation_of @library
    halt 500, "cannot reorganize nonexistent library"
  end

  @floors = @library.floors.sort(&NaturallyCompare[:floors])
  view :libraries_reorganize
end

post Path::Library::REORGANIZE do
  if path_demands_creation_of @library
    halt 500, "cannot reorganize nonexistent library"
  end

  DATA_STORE.transaction do
    # For each floor specified in the reorg form:
    params.each do |key,value|
      key = key.strip.downcase
      value = value.strip

      # detect and extract a floor ID using Ruby's built-in regex (capturing).
      if /^floor-([0-9]+)$/ =~ key
        floor = Floor[Integer($1, 10)]
        if floor.nil?
          halt 500, "cannot reorganize nonexistent floor #{key.inspect}"
        end

        # validate and apply the floor's new order
        if value.empty?
          floor.update(order: nil)
        elsif !(/^([0-9]+)$/ =~ value)
          halt 500, "invalid floor order #{value.inspect}"
        else
          floor.update(order: Integer($1, 10))
        end
      end
    end
  end

  redirect Path::Library::VIEW[@library.id], 303
end
