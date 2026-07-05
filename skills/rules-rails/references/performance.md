---
paths:
  - "**/*.rb"
  - "**/*.erb"
---

# Rails Performance Rules

## N+1 Queries

### DO: Eager load associations (see rails-activerecord.md for full details)

```ruby
# DO
posts = Post.includes(:author, :tags).limit(20)

# DON'T
posts = Post.limit(20)
posts.each { |p| puts p.author.name }  # N+1
```

## Fragment Caching

### DO: Cache rendered partials with cache helper

```erb
<%# DO: cache a partial keyed by the record's cache_key %>
<% cache post do %>
  <%= render "posts/card", post: post %>
<% end %>

<%# DO: Russian Doll -- outer cache wraps inner caches %>
<% cache ["post_list", @posts.maximum(:updated_at)] do %>
  <% @posts.each do |post| %>
    <% cache post do %>
      <%= render "posts/card", post: post %>
    <% end %>
  <% end %>
<% end %>
```

## Low-Level Caching

### DO: Always set TTL for cache entries

```ruby
# DO: expires_in prevents stale data and storage bloat
Rails.cache.fetch("user_#{id}_profile", expires_in: 1.hour) do
  user.build_profile_summary
end

# DO: race_condition_ttl avoids thundering herd on expiry
Rails.cache.fetch("leaderboard", expires_in: 5.minutes, race_condition_ttl: 10.seconds) do
  Leaderboard.compute
end

# DON'T: cache without TTL
Rails.cache.write("all_products", Product.all.to_a)  # never expires; storage bloat
```

## Solid Cache (Rails 8)

### DO: Use Solid Cache for DB-backed caching

```ruby
# DO: config/environments/production.rb (Rails 8 default)
config.cache_store = :solid_cache_store

# DO: set appropriate TTL and size limits in config/solid_cache.yml
# production:
#   store_options:
#     max_size: <%= 256.megabytes %>
#     expiry_batch_size: 400
```

## Background Jobs

### DO: Use Solid Queue (Rails 8) or Sidekiq for async work

```ruby
# DO: Solid Queue -- Rails 8 default, no Redis required
# config/environments/production.rb
config.active_job.queue_adapter = :solid_queue

# Job definition
class SendNewsletterJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.newsletter(user).deliver_now
  end
end

# Enqueue
SendNewsletterJob.perform_later(user.id)

# DON'T: do slow work synchronously in a request
class PostsController < ApplicationController
  def create
    @post = Post.create!(post_params)
    UserMailer.new_post_notification(current_user, @post).deliver_now  # blocks response
  end
end
```

## Counter Cache

### DO: Use counter_cache for association counts

```ruby
# DO: model
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
end

class Post < ApplicationRecord
  has_many :comments
end

# Usage: no COUNT query
post.comments_count  # reads cached column

# DON'T: use comments.count in views (triggers COUNT query per record)
post.comments.count
```

## Pagination

### DO: Paginate large collections with kaminari or pagy

```ruby
# DO: pagy (fastest, lightweight)
@pagy, @posts = pagy(Post.published.recent, items: 20)

# DO: kaminari
@posts = Post.published.recent.page(params[:page]).per(20)

# DON'T: load all records
@posts = Post.published.recent  # potentially thousands of rows
```

## Select and Pluck

### DO: Retrieve only needed columns

```ruby
# DO: pluck for scalar values (no object instantiation)
ids = User.active.pluck(:id)

# DO: select for partial loading (maintains AR objects)
users = User.active.select(:id, :name, :email)

# DON'T: load all columns when heavy columns (blobs, text) are not needed
users = User.active  # loads avatar_data, bio, etc.
```

## Database Indexes

### DO: Index columns used in WHERE, ORDER BY, and JOIN conditions

```ruby
# Migration
add_index :posts, :published_at
add_index :posts, [:author_id, :published_at]  # composite for multi-column queries
add_index :users, :email, unique: true
```
