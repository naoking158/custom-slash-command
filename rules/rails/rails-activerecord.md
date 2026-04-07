---
paths:
  - "**/*.rb"
---

# Rails ActiveRecord Rules

## N+1 Query Prevention

### DO: Use includes / preload / eager_load

```ruby
# DO: includes (Rails chooses strategy automatically)
posts = Post.includes(:author, :tags).limit(20)
posts.each { |p| puts "#{p.author.name}: #{p.tags.map(&:name).join(', ')}" }

# DO: preload (separate queries, good for has_many)
Post.preload(:comments)

# DO: eager_load (LEFT OUTER JOIN, required for WHERE on association)
Post.eager_load(:author).where(authors: { active: true })

# DON'T: lazy loading in loops
posts = Post.limit(20)
posts.each { |p| puts p.author.name }  # N+1: 1 + N author queries
```

### DO: Enable strict_loading to catch N+1 in development

```ruby
# DO: per-query strict loading (Rails 7+)
Post.strict_loading.limit(20)

# DO: model-level strict loading
class Post < ApplicationRecord
  self.strict_loading_by_default = true
end

# DO: config/environments/development.rb
config.active_record.strict_loading_by_default = true
```

## Batch Processing

### DO: Use find_each / find_in_batches for large datasets

```ruby
# DO: memory-efficient iteration
User.find_each(batch_size: 500) do |user|
  UserMailer.newsletter(user).deliver_later
end

# DO: process batches as arrays
User.find_in_batches(batch_size: 500) do |users|
  BulkProcessor.call(users)
end

# DON'T: load entire table into memory
User.all.each { |u| u.do_something }  # loads all records at once
```

## Efficient Queries

### DO: Use pluck for scalar values

```ruby
# DO: pluck returns plain Ruby values (no model objects)
user_ids = User.active.pluck(:id)
emails   = User.where(confirmed: true).pluck(:email)

# DON'T: load full objects when only IDs are needed
user_ids = User.active.map(&:id)        # instantiates all User objects
emails   = User.confirmed.map(&:email)
```

### DO: Use exists? / any? instead of count > 0

```ruby
# DO
return if User.where(email: email).exists?
return if post.comments.any?

# DON'T: count loads all matching records count
return if User.where(email: email).count > 0
return if post.comments.count.positive?
```

### DO: Use select for partial column loading

```ruby
# DO: load only needed columns
users = User.select(:id, :name, :email)

# DON'T: load all columns when few are needed (large text/blob columns)
users = User.all  # includes heavy columns like avatar_data
```

## Transactions

### DO: Wrap multiple writes in a transaction

```ruby
# DO: atomic multi-record operations
ActiveRecord::Base.transaction do
  order.update!(status: :confirmed)
  inventory.decrement!(:stock, order.quantity)
  PaymentRecord.create!(order: order, amount: order.total)
end

# DON'T: multiple writes without transaction
order.update!(status: :confirmed)
inventory.decrement!(:stock, order.quantity)  # may leave partial state on error
```

## Scopes

### DO: Define reusable query scopes

```ruby
# DO: named scopes on the model
class Post < ApplicationRecord
  scope :published, -> { where(published: true) }
  scope :recent,    -> { order(created_at: :desc) }
  scope :by_author, ->(author) { where(author: author) }
end

Post.published.recent.limit(10)

# DON'T: duplicate query logic across controllers/services
Post.where(published: true).order(created_at: :desc)  # repeated everywhere
```

## Indexes

### DO: Add indexes for foreign keys and query columns

```ruby
# DO: in migration
add_index :posts, :author_id                    # foreign key
add_index :posts, [:published, :created_at]     # compound for WHERE + ORDER
add_index :users, :email, unique: true          # uniqueness constraint

# DON'T: forget indexes on frequently queried columns
# Missing index on posts.author_id causes full table scan on JOIN
```

## Raw SQL

### DON'T: Use raw SQL when ActiveRecord suffices

```ruby
# DON'T
results = ActiveRecord::Base.connection.execute(
  "SELECT * FROM users WHERE role = '#{role}'"  # also SQL injection risk
)

# DO
User.where(role: role)
```
