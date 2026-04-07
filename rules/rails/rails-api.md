---
paths:
  - "app/controllers/api/**/*.rb"
  - "**/*.rb"
---

# Rails API Rules

## Versioning

### DO: Use URL prefix and module namespace for API versioning

```ruby
# DO: config/routes.rb
namespace :api do
  namespace :v1 do
    resources :users, only: [:index, :show, :create, :update]
    resources :posts
  end
end

# DO: app/controllers/api/v1/users_controller.rb
module Api
  module V1
    class UsersController < Api::BaseController
      def index
        users = User.active.page(params[:page])
        render json: UserSerializer.new(users).serializable_hash
      end
    end
  end
end

# DON'T: version in Accept header only (harder to test, route, and cache)
# DON'T: no versioning at all
```

## Base Controller

### DO: Create a dedicated API base controller

```ruby
# DO: app/controllers/api/base_controller.rb
module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_request!
    rescue_from ActiveRecord::RecordNotFound,     with: :render_not_found
    rescue_from ActiveRecord::RecordInvalid,      with: :render_unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :render_bad_request

    private

    def render_not_found(exception)
      render_error(:not_found, exception.message)
    end

    def render_unprocessable_entity(exception)
      render_error(:unprocessable_entity, exception.record.errors.full_messages)
    end

    def render_bad_request(exception)
      render_error(:bad_request, exception.message)
    end

    def render_error(status, errors)
      render json: { errors: Array(errors) }, status: status
    end
  end
end
```

## HTTP Status Codes

### DO: Use semantic HTTP status codes

```ruby
# DO
render json: @user,  status: :ok           # 200 GET/PUT success
render json: @post,  status: :created      # 201 POST success
head :no_content                            # 204 DELETE success
render json: errors, status: :bad_request  # 400 invalid request
render json: errors, status: :unauthorized # 401 not authenticated
render json: errors, status: :forbidden    # 403 not authorized
render json: errors, status: :not_found    # 404 record not found
render json: errors, status: :unprocessable_entity  # 422 validation errors

# DON'T: always return 200 with error in body
render json: { success: false, message: "Not found" }, status: :ok
```

## Serializers

### DO: Use jsonapi-serializer or jbuilder for response shaping

```ruby
# DO: jsonapi-serializer
class UserSerializer
  include JSONAPI::Serializer

  attributes :id, :name, :email, :created_at

  attribute :full_name do |user|
    "#{user.first_name} #{user.last_name}"
  end

  has_many :posts
end

render json: UserSerializer.new(@user).serializable_hash

# DO: jbuilder (built-in with Rails)
# app/views/api/v1/users/show.json.jbuilder
json.id      @user.id
json.name    @user.full_name
json.email   @user.email
```

## Error Response Format

### DO: Use consistent error JSON structure

```ruby
# DO: consistent error envelope
{
  "errors": [
    { "field": "email", "message": "has already been taken" },
    { "field": "name",  "message": "can't be blank" }
  ]
}

# DON'T: inconsistent formats across endpoints
{ "error": "email taken" }           # endpoint A
{ "message": "Validation failed" }   # endpoint B
{ "errors": { "email": ["taken"] } } # endpoint C
```

## Authentication

### DO: Use token-based authentication for API endpoints

```ruby
# DO: Bearer token in Authorization header
class Api::BaseController < ActionController::API
  before_action :authenticate_api_request!

  private

  def authenticate_api_request!
    token = request.headers["Authorization"]&.sub(/\ABearer /, "")
    @current_api_user = ApiToken.find_by(token: token)&.user
    render_error(:unauthorized, "Invalid or missing token") unless @current_api_user
  end
end
```

## Pagination

### DO: Include pagination metadata in response

```ruby
# DO: Link header (RFC 5988) + meta object
class Api::V1::PostsController < Api::BaseController
  def index
    @pagy, @posts = pagy(Post.published.recent)
    response.set_header("Link", pagy_link_header(@pagy))
    render json: {
      data: PostSerializer.new(@posts).serializable_hash,
      meta: { total: @pagy.count, pages: @pagy.pages, page: @pagy.page }
    }
  end
end
```

## Rate Limiting

### DO: Protect API endpoints with rack-attack

```ruby
# DO: config/initializers/rack_attack.rb
Rack::Attack.throttle("api/token", limit: 300, period: 5.minutes) do |req|
  req.env["HTTP_AUTHORIZATION"] if req.path.start_with?("/api/")
end

Rack::Attack.throttle("api/ip", limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api/")
end
```
