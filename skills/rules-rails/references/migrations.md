---
paths:
  - "db/migrate/**/*.rb"
  - "**/*.rb"
---

# Rails Migrations Rules

## Single Responsibility

### DO: One migration = one logical change

```ruby
# DO: separate migrations for separate concerns
# 20240101000001_add_status_to_orders.rb
class AddStatusToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :status, :integer, default: 0, null: false
    add_index  :orders, :status
  end
end

# DON'T: combine unrelated changes
class AddStuffToMultipleTables < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :status, :integer
    add_column :users, :phone, :string
    rename_column :products, :cost, :price
  end
end
```

## Reversible Migrations

### DO: Use change method for reversible operations

```ruby
# DO: change is automatically reversible
class AddPublishedAtToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :published_at, :datetime
    add_index  :posts, :published_at
  end
end

# DO: use reversible block when change is not invertible
class MigrateUserNames < ActiveRecord::Migration[8.0]
  def change
    reversible do |dir|
      dir.up do
        User.find_each do |user|
          user.update_columns(
            first_name: user.name.split.first,
            last_name:  user.name.split.last
          )
        end
      end
      dir.down do
        User.find_each do |user|
          user.update_column(:name, "#{user.first_name} #{user.last_name}")
        end
      end
    end
  end
end
```

## Naming Conventions

### DO: Use descriptive migration names

```ruby
# DO: name reflects the exact change
AddEmailToUsers
RemoveDeprecatedColumnFromProducts
CreateSubscriptionsTable
AddIndexOnPostsPublishedAt

# DON'T: vague names
UpdateUsers
FixStuff
Migration20240101
```

## NOT NULL Constraints and Defaults

### DO: Provide default values with NOT NULL columns

```ruby
# DO: safe in production (default prevents lock on large tables)
class AddActiveToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :active, :boolean, default: true, null: false
  end
end

# DON'T: NOT NULL without default blocks inserts until data is backfilled
class AddActiveToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :active, :boolean, null: false  # will fail on existing rows
  end
end
```

## Foreign Key Constraints

### DO: Declare foreign keys explicitly

```ruby
# DO
class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.timestamps
    end
  end
end

# Also valid: explicit add_foreign_key
add_foreign_key :posts, :users
```

## Production Safety

### DO: Use strong_migrations gem for dangerous operation detection

```ruby
# Gemfile
gem "strong_migrations"

# strong_migrations will warn/block on:
# - adding a NOT NULL column without default
# - removing a column without a backfill step
# - changing a column type on a large table
# - adding an index without :algorithm => :concurrently
```

### DO: Add indexes concurrently in production

```ruby
# DO: non-blocking index creation
class AddIndexOnUsersEmail < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

## Data Migrations

### DON'T: Mix schema changes and data backfills in the same migration

```ruby
# DON'T: risky -- schema and data together
class AddFullNameToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :full_name, :string
    User.find_each { |u| u.update_column(:full_name, "#{u.first} #{u.last}") }
    change_column_null :users, :full_name, false
  end
end

# DO: use data_migrate gem for separate data migration files
# db/data/20240101000001_backfill_full_name.rb
class BackfillFullName < ActiveRecord::DataMigration
  def up
    User.find_each { |u| u.update_column(:full_name, "#{u.first} #{u.last}") }
  end
end
```

## schema.rb

### DO: Always commit schema.rb alongside migration files

```bash
# After running rails db:migrate, commit both files
git add db/migrate/20240101000001_add_status_to_orders.rb db/schema.rb
git commit -m "Add status column to orders"
```
