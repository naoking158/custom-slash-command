---
paths:
  - "**/*.rb"
---

# Rails Architecture Rules

## Skinny Controller, Fat Model

### DO: Keep controllers focused on HTTP concerns

```ruby
# DO: delegate business logic to the model / service
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    if @order.place(current_user)
      redirect_to @order, notice: "Order placed."
    else
      render :new, status: :unprocessable_entity
    end
  end
end

# DON'T: business logic inside the controller
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    @order.total = @order.items.sum(&:price)
    @order.tax   = @order.total * 0.1
    InventoryService.reserve(@order.items)
    @order.save!
    OrderMailer.confirmation(@order).deliver_later
    redirect_to @order
  end
end
```

## Strong Parameters

### DO: Use params.expect (Rails 8) or require/permit (Rails 7.x)

```ruby
# DO (Rails 8): params.expect for type-safe strong parameters
def user_params
  params.expect(user: [:name, :email, { role_ids: [] }])
end

# ACCEPTABLE (Rails 7.x): require + permit is the standard
# PREFER params.expect in Rails 8+ for improved type safety
def user_params
  params.require(:user).permit(:name, :email, role_ids: [])
end

# DON'T: skip or bypass strong parameters
def user_params
  params[:user]   # unfiltered
end
```

## Concerns

### DO: Use Concerns only for cross-model shared behaviour

```ruby
# DO: shared across multiple models
module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable
    has_many :tags, through: :taggings
  end

  def tag_list
    tags.pluck(:name).join(", ")
  end
end

class Post < ApplicationRecord
  include Taggable
end

class Video < ApplicationRecord
  include Taggable
end

# DON'T: concern just to reduce a single model's line count
module UserAdminHelpers  # only used by User model
  extend ActiveSupport::Concern
  # 50 lines hidden here...
end
```

## Service Objects

### DO: Model domain actions as plain Ruby objects

```ruby
# DO: domain-oriented name
class PlaceOrder
  def initialize(cart, user)
    @cart = cart
    @user = user
  end

  def call
    ActiveRecord::Base.transaction do
      order = Order.create!(user: @user, total: @cart.total)
      @cart.items.each { |item| order.line_items.create!(item.attributes) }
      InventoryReserver.new(order).reserve!
      order
    end
  end
end

# DON'T: -er suffix service names (implies procedural, not domain)
class OrderCreator; end
class OrderProcessor; end
```

## Validations

### DO: Define validations in the model

```ruby
# DO: model-level validations
class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age,   numericality: { greater_than: 0 }, allow_nil: true
end

# DO: custom validators in app/validators/
class EmailDomainValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless ALLOWED_DOMAINS.include?(value.split("@").last)
      record.errors.add(attribute, :invalid_domain)
    end
  end
end
```

## Enums

### DO: Use enum to replace magic numbers/strings

```ruby
# DO
class Order < ApplicationRecord
  enum :status, { pending: 0, confirmed: 1, shipped: 2, cancelled: 3 }
end

order.confirmed?
order.confirmed!
Order.shipped

# DON'T: raw integers or string constants scattered across the codebase
order.status == 1         # what does 1 mean?
order.status == "shipped"
```

## Callbacks

### DO: Keep callbacks minimal and side-effect free

```ruby
# DO: simple lifecycle hook
class User < ApplicationRecord
  after_create :send_welcome_email

  private

  def send_welcome_email
    UserMailer.welcome(self).deliver_later
  end
end

# DON'T: complex chained callbacks with external side effects
class Order < ApplicationRecord
  after_save   :update_inventory       # triggers another save
  after_create :notify_warehouse       # network call
  before_save  :recalculate_totals     # business logic
  after_commit :sync_to_crm            # external API in hot path
end
```

## Authentication (Rails 8)

### DO: Use Rails 8 authentication generator for new projects

```bash
# Generates Session, Current, User models + controllers with secure defaults
rails generate authentication
```

Adds `before_action :require_authentication` to `ApplicationController` by default.
