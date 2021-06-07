# BodyBuilder

An elasticsearch query body builder. Easily build complex queries for elasticsearch with a simple, predictable api. Based on https://github.com/danpaz/bodybuilder!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'body_builder'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install body_builder

## Usage

Create a new builder by instantiating the `BodyBuilder::Builder`
```ruby
builder = BodyBuilder::Builder.new
```

To add clauses, the following methods are available:

Filter context:
- `filter` (alias: and_filter)
- `or_filter`
- `not_filter`

Query context:
- `query` (alias: and_query)
- `or_query`
- `not_query`

Other useful methods are:
- `raw_option`
- `sort_field`
- `size`
- `from`

Lets create our first query:

```ruby
builder.query('match_all')
builder.build() #=> { "query": { "match_all": {} } }
```

We can continue adding clauses.. ToDo




For more examples, check tests

### Nesting




## ToDo:
- `agg`
- `suggestion`




## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/body_builder.
