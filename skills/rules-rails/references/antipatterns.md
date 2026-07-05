---
paths:
  - "**/*.rb"
---

# Rails Antipatterns

## Fat Controller

### DON'T: Put business logic in controllers

```ruby
# DON'T
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    @order.total = @order.items.sum { |i| i.price * i.quantity }
    @order.tax   = @order.total * Tax.rate_for(@order.user.country)
    if @order.total > 1000
      @order.discount = @order.total * 0.1
    end
    InventoryService.reserve!(@order.items)
    @order.save!
    OrderMailer.confirmation(@order).deliver_later
    redirect_to @order
  end
end

# DO: delegate to a domain object / service
class OrdersController < ApplicationController
  def create
    result = PlaceOrder.new(order_params, current_user).call
    if result.success?
      redirect_to result.order
    else
      @order = result.order
      render :new, status: :unprocessable_entity
    end
  end
end
```

## God Model

### DON'T: Let one model accumulate all responsibilities

```ruby
# DON'T: User model with 500+ lines handling auth, billing, notifications, etc.
class User < ApplicationRecord
  # authentication
  # billing / subscription logic
  # notification preferences
  # analytics tracking
  # social graph
  # ...
end

# DO: extract focused concerns and service objects
class User < ApplicationRecord
  include Authenticatable  # shared across models? use concern
  has_one :subscription
  has_many :notifications
end

class Subscription < ApplicationRecord
  # billing logic lives here
end
```

## Excessive Callbacks

### DON'T: Chain multiple callbacks with external side effects

```ruby
# DON'T: unpredictable execution order; hard to test
class Order < ApplicationRecord
  after_save   :update_inventory
  after_create :notify_warehouse
  after_commit :sync_to_crm
  before_save  :recalculate_totals
end

# DO: explicit method calls in a service object
class PlaceOrder
  def call
    recalculate_totals
    order.save!
    update_inventory
    notify_warehouse
    sync_to_crm
  end
end
```

## Service Object Naming

### DON'T: Use -er/-or suffix service names

```ruby
# DON'T: sounds procedural, not domain-oriented
class UserCreator; end
class OrderProcessor; end
class PaymentHandler; end

# DO: use action-oriented or domain-model names
class CreateUser; end          # command name
class PlaceOrder; end          # domain action
class ProcessRefund; end       # acceptable for financial processes
```

## Concern Misuse

### DON'T: Use Concerns only to reduce a single model's line count

```ruby
# DON'T: concern included only in User, just hiding complexity
module UserProfileHelpers
  extend ActiveSupport::Concern
  # ...100 lines only used by User...
end

class User < ApplicationRecord
  include UserProfileHelpers  # hiding complexity, not sharing it
end

# DO: concerns for genuinely shared behaviour
module Searchable
  extend ActiveSupport::Concern
  included do
    include Elasticsearch::Model
  end
end

class Post < ApplicationRecord; include Searchable; end
class Product < ApplicationRecord; include Searchable; end
```

## Exception-Driven Control Flow

### DON'T: Use exceptions for expected cases

```ruby
# DON'T
def find_user(id)
  User.find(id)  # raises ActiveRecord::RecordNotFound as flow control
rescue ActiveRecord::RecordNotFound
  nil
end

# DO
def find_user(id)
  User.find_by(id: id)  # returns nil naturally
end
```

## default_scope

### DON'T: Add default_scope — it leaks into every query

```ruby
# DON'T: hides query conditions, causes surprising behaviour
class Post < ApplicationRecord
  default_scope { where(published: true).order(:created_at) }
end

Post.count          # only counts published posts — surprising!
Post.unscoped.count # must explicitly opt out everywhere

# DO: use explicit named scopes
class Post < ApplicationRecord
  scope :published, -> { where(published: true) }
end

Post.published.count   # intent is clear
Post.count             # all posts
```

## Skip Validations

### DON'T: Bypass validations without a documented reason

```ruby
# DON'T: silently skips all validations
user.update_column(:email, new_email)
user.save(validate: false)

# DO: fix the validation or use a specific bypass with a comment
# EXCEPTION: data migration where speed is critical and data is pre-validated
User.where(legacy: true).in_batches.update_all(migrated: true)
```

## Nested Transactions

### DON'T: Assume nested transactions provide independent rollback

A rollback inside a nested `transaction` block rolls back the outer transaction too.
Keep a single explicit transaction boundary in a service object instead of nesting across service calls.
