class ActionController::Routing::Route
  def recognition_conditions_with_facebooker
    defaults = recognition_conditions_without_facebooker 
    defaults << " env[:canvas] == conditions[:canvas] " if conditions[:canvas]
    defaults
  end
  alias_method_chain :recognition_conditions, :facebooker
end

# We turn off route optimization to make named routes use our code for figuring out if they should go to the session
#
# SSS: Commenting this off since this interferes with named_route generation in our app!
# Since we aren't using this as a facebook-native app, this is just fine!
#
#ActionController::Base::optimise_named_routes = false 

# pull :canvas=> into env in routing to allow for conditions
ActionController::Routing::RouteSet.send :include,  Facebooker::Rails::Routing::RouteSetExtensions
ActionController::Routing::RouteSet::Mapper.send :include, Facebooker::Rails::Routing::MapperExtensions
