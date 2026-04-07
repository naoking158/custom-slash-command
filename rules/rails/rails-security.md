---
paths:
  - "**/*.rb"
  - "**/*.erb"
---

# Rails Security Rules

## SQL Injection Prevention

### DO: Use parameterized queries or hash conditions

```ruby
# DO: placeholder syntax
User.where("email = ?", params[:email])
User.where("created_at > ?", 1.week.ago)

# DO: hash syntax (preferred)
User.where(email: params[:email])

# DON'T: string interpolation in SQL
User.where("email = '#{params[:email]}'")
User.joins("INNER JOIN roles ON roles.id = #{params[:role_id]}")
```

## Strong Parameters

### DO: Use params.expect (Rails 8) or require/permit (Rails 7.x)

```ruby
# DO (Rails 8): params.expect for type-safe strong parameters
def user_params
  params.expect(user: [:name, :email, { roles: [] }])
end

# ACCEPTABLE (Rails 7.x)
def user_params
  params.require(:user).permit(:name, :email, roles: [])
end

# DON'T: permit all or skip strong parameters
def user_params
  params[:user]            # no filtering
  params.permit!           # allows all
end
```

## XSS Prevention

### DO: Trust ERB auto-escaping; avoid raw HTML output

```erb
<%# DO: auto-escaped by default %>
<p><%= @user.name %></p>

<%# DON'T: bypass escaping without sanitization %>
<p><%= raw @user.bio %></p>
<p><%= @user.bio.html_safe %></p>

<%# DO: when HTML is needed, sanitize explicitly %>
<p><%= sanitize @user.bio, tags: %w[b i em strong p] %></p>
```

## CSRF Protection

### DO: Keep protect_from_forgery enabled

```ruby
# DO: ApplicationController (default in Rails)
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
end

# DON'T: disable CSRF protection globally
class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token  # dangerous
end

# OK: disable only for API endpoints with token auth
class Api::V1::BaseController < ActionController::API
  # ActionController::API does not include CSRF by default
end
```

## Authentication

### DO: Use Rails 8 built-in authentication generator

```bash
# DO: Rails 8 authentication generator (zero external dependencies)
rails generate authentication

# ACCEPTABLE: Devise for advanced requirements (OAuth, confirmable, etc.)
# gem "devise"
```

```ruby
# DO: authenticate in ApplicationController
class ApplicationController < ActionController::Base
  before_action :require_authentication
end
```

## Authorization

### DO: Enforce authorization with Pundit or CanCanCan

```ruby
# DO: Pundit policy
class PostPolicy < ApplicationPolicy
  def update?
    user.admin? || record.author == user
  end
end

class PostsController < ApplicationController
  def update
    @post = Post.find(params[:id])
    authorize @post
    # ...
  end
end

# DON'T: inline authorization logic in controllers
def update
  @post = Post.find(params[:id])
  raise "Forbidden" unless current_user.admin? || @post.author == current_user
end
```

## Secrets Management

### DO: Use Rails credentials for sensitive values

```ruby
# DO: access via credentials
Rails.application.credentials.secret_key_base
Rails.application.credentials.dig(:aws, :access_key_id)

# DON'T: hard-code secrets or commit .env files with real secrets
API_KEY = "sk-live-abc123"  # never commit real secrets
```

## HTTPS

### DO: Force SSL in production

```ruby
# DO: config/environments/production.rb
config.force_ssl = true
```

## Security Tooling

### DO: Integrate Brakeman and bundler-audit in CI

```bash
# Static analysis for security vulnerabilities
bundle exec brakeman --no-pager

# Dependency vulnerability scanning
bundle exec bundler-audit check --update
```

### DO: Rate-limit with rack-attack

```ruby
# DO: config/initializers/rack_attack.rb
Rack::Attack.throttle("api/ip", limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api/")
end
```
