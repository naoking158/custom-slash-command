---
paths:
  - "spec/**/*.rb"
  - "test/**/*.rb"
  - "**/*.rb"
---

# Rails Testing Rules

## Test Pyramid

### DO: Follow the test pyramid: Unit > Integration > System

```
Unit Tests      (many)   - Models, validators, service objects, helpers
Integration Tests (some) - Controller/request specs, mailers, jobs
System Tests    (few)    - End-to-end browser flows with Capybara
```

## Minitest (Rails Default)

### DO: Use Minitest for new Rails 8 projects

```ruby
# DO: test/models/user_test.rb
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "full_name concatenates first and last name" do
    user = User.new(first_name: "Alice", last_name: "Smith")
    assert_equal "Alice Smith", user.full_name
  end

  test "email must be unique" do
    users(:alice).dup.tap do |u|
      assert_not u.valid?
      assert_includes u.errors[:email], "has already been taken"
    end
  end
end

# DO: request integration test
class PostsControllerTest < ActionDispatch::IntegrationTest
  test "GET /posts returns 200" do
    get posts_path
    assert_response :success
  end

  test "POST /posts creates post for authenticated user" do
    sign_in users(:alice)
    assert_difference "Post.count", 1 do
      post posts_path, params: { post: { title: "Hello", body: "World" } }
    end
    assert_redirected_to post_path(Post.last)
  end
end
```

## RSpec (Team Adoption)

### DO: Use describe/context/it structure with let and subject

```ruby
# DO: spec/models/user_spec.rb
RSpec.describe User do
  subject(:user) { build(:user) }

  describe "#full_name" do
    it "concatenates first and last name" do
      user = build(:user, first_name: "Alice", last_name: "Smith")
      expect(user.full_name).to eq("Alice Smith")
    end
  end

  describe "validations" do
    context "when email is missing" do
      before { user.email = nil }

      it { is_expected.to be_invalid }
      it { expect(user.errors[:email]).to include("can't be blank") }
    end
  end

  shared_examples "a timestamped record" do
    it { is_expected.to respond_to(:created_at, :updated_at) }
  end

  it_behaves_like "a timestamped record"
end
```

## FactoryBot

### DO: Prefer build / build_stubbed over create

```ruby
# DO: no DB hit
user = build(:user)
user = build_stubbed(:user)

# DO: use create only when DB persistence is required
user = create(:user)
post = create(:post, author: user)

# DON'T: always create records (slow tests)
let(:user) { create(:user) }  # DB hit even for pure unit tests
```

### DO: Keep factories minimal; use traits for variants

```ruby
# DO
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "Alice" }
    last_name  { "Smith" }
    password   { "password123" }

    trait :admin do
      role { :admin }
    end

    trait :inactive do
      active { false }
    end
  end
end

create(:user, :admin)
build(:user, :inactive)
```

## External API Mocking

### DO: Use WebMock or VCR to stub external requests

```ruby
# DO: WebMock stub
stub_request(:get, "https://api.example.com/users/1")
  .to_return(status: 200, body: { id: 1, name: "Alice" }.to_json,
             headers: { "Content-Type" => "application/json" })

# DO: VCR cassette for recorded interactions
VCR.use_cassette("github_user") do
  response = GithubClient.fetch_user("alice")
  expect(response[:login]).to eq("alice")
end
```

## System Tests

### DO: Use Capybara with headless browser for critical flows

```ruby
# DO: test/system/checkouts_test.rb
class CheckoutsTest < ApplicationSystemTestCase
  driven_by :selenium, using: :headless_chrome

  test "user can complete checkout" do
    sign_in users(:alice)
    visit cart_path
    click_on "Checkout"
    fill_in "Card number", with: "4242 4242 4242 4242"
    click_on "Pay"
    assert_text "Order confirmed"
  end
end
```

## Coverage

### DO: Aim for 80%+ line coverage with SimpleCov

```ruby
# DO: test/test_helper.rb or spec/spec_helper.rb
require "simplecov"
SimpleCov.start "rails" do
  minimum_coverage 80
  add_filter "/test/"
  add_filter "/spec/"
end
```

## Common Mistakes

### DON'T: Test private methods directly

Test through the public interface. Refactor if private logic is complex enough to test independently.

### DON'T: Use sleep in tests

```ruby
# DON'T
sleep 2
assert_text "Done"

# DO: use Capybara's built-in waiting
assert_text "Done"  # Capybara retries until timeout
```
