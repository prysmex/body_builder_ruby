# BodyBuilder

An elasticsearch query body builder. Easily build complex queries for elasticsearch with a simple, predictable api. Based on [body builder js](https://github.com/danpaz/bodybuilder), try it online [here!](https://bodybuilder.js.org/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'body_builder'
```

And then execute:

```bash
bundle
```

Or install it yourself as:

```bash
gem install body_builder
```

## TODOs

- support aggregations
- support suggestions

## Basic Usage

Lets create our first query by using the `BodyBuilder::Builder` class

```ruby
builder = BodyBuilder::Builder.new
builder.filter('terms', 'tags', ['Emerging'])
builder.build
# => {
#   "query": {
#     "bool": {
#       "filter": {
#         "terms": {
#           "tags": [
#             "Emerging"
#           ]
#         }
#       }
#     }
#   }
# }
```

That was easy, let's do something more interesting

```ruby
builder.filter('terms', 'state', ['done'])
builder.query('match', 'name', 'John')
builder.build
# => {
#   "query": {
#     "bool": {
#       "filter": {
#         "bool": {
#           "must": [
#             {
#               "terms": {
#                 "tags": [
#                   "Emerging"
#                 ]
#               }
#             },
#             {
#               "terms": {
#                 "state": [
#                   "done"
#                 ]
#               }
#             }
#           ]
#         }
#       },
#       "must": {
#         "match": {
#           "name": "John"
#         }
#       }
#     }
#   }
# }
```

Most methods return the `Builder` instance to allow easy chaining. Lets redo the previous
example.

```ruby
BodyBuilder::Builder.new
    .filter('terms', 'tags', ['Emerging'])
    .filter('terms', 'state', ['done'])
    .query('match', 'name', 'John')
    .build
```

When using the `BodyBuilder::Builder` class contains multiple methods that help
create powerful queries. They are mainly divided into 2 categories:

- filter context
  - `filter` (alias: and_filter)
  - `or_filter`
  - `not_filter`
  - `set_filter_minimum_should_match`

- query context
  - `query` (alias: and_query)
  - `or_query`
  - `not_query`
  - `set_query_minimum_should_match`

You can combine the previous methods all you want to create complex queries in just a few lines of code.
For more examples, refer to the specs.

### From / Size 

use `set_size` and `set_from` for pagination
```ruby
BodyBuilder::Builder.new
  .query('match_all')
  .set_size(25)
  .set_from(10)
  .build
# => {
#   "query": {
#     "match_all": {}
#   },
#   "size": 25,
#   "from": 10
# }
```

### Sorting

```ruby
BodyBuilder::Builder.new
  .query('match_all')
  .sort_field('id', 'desc')
  .sort_field('updated_at', 'desc')
  .build
# {
#   "query": {
#     "match_all": {}
#   },
#   "sort": [
#     {
#       "id": "desc"
#     },
#     {
#       "updated_at": "desc"
#     }
#   ]
# }
```

### Raw option

```ruby
BodyBuilder::Builder.new
  .query('match_all')
  .raw_option('source', ['id'])
  .build
# {
#   "query": {
#     "match_all": {}
#   },
#   "source": [
#     "id"
#   ]
# }
```

### Other methods

- `queries?`
- `filters?`

### Reset

This methods allow to remove previously added data to a `Builder` instance:
- `reset!`
- `reset_queries!`
- `reset_filters!`
- `reset_raw_options!`
- `reset_sort_fields!`