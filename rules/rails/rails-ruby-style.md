---
paths:
  - "**/*.rb"
---

# Ruby Style Rules

## Indentation and Formatting

### DO: Use 2 spaces for indentation (no tabs)

```ruby
# DO
class User
  def full_name
    "#{first_name} #{last_name}"
  end
end

# DON'T: tabs or 4-space indent
class User
	def full_name   # tab indented
    "#{first_name} #{last_name}"
    end
end
```

## Naming Conventions

### DO: Use snake_case for methods and variables

```ruby
# DO
user_name = "Alice"
def calculate_total_price(items); end

# DON'T
userName = "Alice"
def calculateTotalPrice(items); end
```

### DO: Use PascalCase for classes and modules

```ruby
# DO
class OrderProcessor; end
module PaymentGateway; end

# DON'T
class order_processor; end
module payment_gateway; end
```

### DO: Use SCREAMING_SNAKE_CASE for constants

```ruby
# DO
MAX_RETRY_COUNT = 3
DEFAULT_TIMEOUT = 30

# DON'T
maxRetryCount = 3
default_timeout = 30
```

### DO: Prefix unused variables with underscore

```ruby
# DO
result.each_with_index do |item, _index|
  process(item)
end

# DON'T
result.each_with_index do |item, index|  # index unused, but no warning suppression
  process(item)
end
```

## Accessor Methods

### DON'T: Use get_/set_ prefixes

```ruby
# DON'T
def get_name; @name; end
def set_name(val); @name = val; end

# DO: use Ruby conventions
attr_accessor :name

# DO: custom reader/writer
def name
  @name.to_s.strip
end

def name=(val)
  @name = val.to_s.downcase
end
```

## Frozen String Literal

### DO: Add frozen_string_literal magic comment

```ruby
# DO: top of every .rb file
# frozen_string_literal: true

class MyClass
  GREETING = "hello"  # frozen, no runtime freeze needed
end
```

## Logical Operators

### DO: Use && / || in conditions; and/or only for control flow

```ruby
# DO: conditions use && / ||
if user.admin? && user.active?
  grant_access
end

value = cached_value || compute_value

# DON'T: and/or in conditions (lower precedence, confusing)
if user.admin? and user.active?  # parsed differently
  grant_access
end

# OK: and/or as control flow (uncommon)
load_config or raise "Config missing"
```

## Method Length

### DO: Keep methods under 10 lines; classes under 100 lines

Each method should have a single responsibility. Extract helpers when a method grows beyond 10 lines.

## Pattern Matching (Ruby 3.x)

### DO: Use pattern matching for complex data deconstruction

```ruby
# DO: Ruby 3.x pattern matching
case response
in { status: 200, body: { user: { name: String => name } } }
  "Welcome, #{name}"
in { status: 404 }
  "Not found"
in { status: (500..) => code }
  "Server error: #{code}"
end

# DO: find pattern
users.each do |user|
  case user
  in { role: "admin", active: true }
    promote(user)
  end
end
```

## Documentation

### DO: Use YARD format for public APIs

```ruby
# DO
# Returns the formatted display name for the user.
#
# @param include_email [Boolean] whether to append the email address
# @return [String] formatted name string
def display_name(include_email: false)
  base = "#{first_name} #{last_name}"
  include_email ? "#{base} <#{email}>" : base
end
```

## RuboCop Compliance

### DO: Maintain a .rubocop.yml with rubocop-rails and rubocop-performance

Include `rubocop-rails` and `rubocop-performance` extensions. Set `TargetRubyVersion: 3.2` and `NewCops: enable` in `AllCops`.
