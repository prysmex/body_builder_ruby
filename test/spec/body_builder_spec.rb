require 'test_helper'
require 'json'
require 'byebug'

module BuilderTestMethods
  def setup
    @builder = BodyBuilder::Builder.new
  end
end

class HelperTest < Minitest::Test

  include BuilderTestMethods

  def compare_jsons(a, b)
    assert_equal JSON.generate(a), JSON.generate(b)
  end

  def test_respond_to_methods
    #query
    assert_respond_to @builder, :query
    assert_respond_to @builder, :and_query
    assert_respond_to @builder, :or_query
    assert_respond_to @builder, :not_query

    #filter
    assert_respond_to @builder, :filter
    assert_respond_to @builder, :and_filter
    assert_respond_to @builder, :or_filter
    assert_respond_to @builder, :not_filter

    #other
    assert_respond_to @builder, :base_query
    assert_respond_to @builder, :raw_option
    assert_respond_to @builder, :sort_field
  end

  def test_size
    a = @builder
        .set_size(5)
        .build
    b = { "size": 5 }
    compare_jsons(a, b)
  end

  def test_from
    a = @builder
        .set_from(50)
        .build
    b = { "from": 50 }
    compare_jsons(a, b)
  end

  def test_raw_option
    a = @builder
        .raw_option(:size, 5)
        .build
    b = { "size": 5 }
    compare_jsons(a, b)
  end

  def test_sort_field
    a = @builder
        .sort_field(:id, 'desc')
        .build
    b = { "sort": [{id: 'desc'}] }
    compare_jsons(a, b)
  end

  def test_override_sort_field
    a = @builder
        .sort_field(:id, 'desc')
        .sort_field(:id, 'asc')
        .build
    b = { "sort": [{id: 'asc'}] }
    compare_jsons(a, b)
  end

  ######
  #ARGS#
  ######

  def test_single_query_1_arg
    a = @builder
        .query('match_all')
        .build
    b = { "query": { "match_all": {} } }
    compare_jsons(a, b)
  end

  def test_single_query_2_args
    a = @builder
        .query('exists', 'user')
        .build
    b = { "query": { "exists": { "field": "user" } } }
    compare_jsons(a, b)
  end

  def test_single_query_3_args
    a = @builder
        .query('range', 'date', {gt: 'now-1d'})
        .build()
    b = { "query": { "range": { "date": { "gt": "now-1d" } } } }
    compare_jsons(a, b)
  end

  def test_single_query_4_args
    a = @builder
        .query('geo_distance', 'point', {lat: 40, lon: 20}, {distance: '12km'})
        .build()
    b = { "query": { "geo_distance": { "point": { "lat": 40, "lon": 20 }, "distance": "12km" } } }
    compare_jsons(a, b)
  end

  #########
  #FILTERS#
  #########

  # SINGLES

  def test_single_filter
    a = @builder
        .filter('terms', 'tags', ['Emerging'])
        .build
    b = { "query": { "bool": { "filter": { "terms": { "tags": [ "Emerging" ] } } } } }
    compare_jsons(a, b)
  end

  def test_single_and_filter
    a = @builder
        .and_filter('terms', 'tags', ['Emerging'])
        .build
    b = { "query": { "bool": { "filter": { "terms": { "tags": [ "Emerging" ] } } } } }
    compare_jsons(a, b)
  end

  def test_single_or_filter
    a = @builder
        .or_filter('terms', 'tags', ['Emerging'])
        .build
    b = { "query": { "bool": { "filter": { "bool": { "should": { "terms": { "tags": [ "Emerging" ] } } } } } } }
    compare_jsons(a, b)
  end

  def test_single_not_filter
    a = @builder
        .not_filter('terms', 'tags', ['Emerging'])
        .build
    b = { "query": { "bool": { "must_not": { "terms": { "tags": [ "Emerging" ] } } } } }
    compare_jsons(a, b)
  end

  #COMBINED
  def test_combined_filters
    a = @builder
        .filter('terms', 'tags', 'filter')
        .or_filter('terms', 'tags', 'or_filter')
        .not_filter('terms', 'tags', 'not_filter')
        .build
    b = { "query": { "bool": { "filter": { "bool": { "must": { "terms": { "tags": "filter" } }, "should": { "terms": { "tags": "or_filter" } }, "must_not": { "terms": { "tags": "not_filter" } } } } } } }
    compare_jsons(a, b)
  end

  #DUPLICATED

  #######
  #QUERY#
  #######

  # SINGLES

  def test_single_query
    a = @builder
        .query('match', 'tags', 'Emerging')
        .build
    b = { "query": { "match": { "tags": "Emerging" } } }
    compare_jsons(a, b)
  end

  def test_single_and_query
    a = @builder
        .query('match', 'tags', 'Emerging')
        .build
    b = { "query": { "match": { "tags": "Emerging" } } }
    compare_jsons(a, b)
  end

  def test_single_or_query
    a = @builder
        .or_query('terms', 'tags', ['Emerging'])
        .build()
    b = { "query": { "bool": { "should": { "terms": { "tags": [ "Emerging" ] } } } } }
    compare_jsons(a, b)
  end

  def test_single_not_query
    a = @builder
        .not_query('terms', 'tags', ['Emerging'])
        .build()
    b = { "query": { "bool": { "must_not": { "terms": { "tags": [ "Emerging" ] } } } } }
    compare_jsons(a, b)
  end

  #COMBINED
  def test_combined_querys
    a = @builder
        .query('terms', 'tags', 'query')
        .or_query('terms', 'tags', 'or_query')
        .not_query('terms', 'tags', 'not_query')
        .build
    b = { "query": { "bool": { "must": { "terms": { "tags": "query" } }, "should": { "terms": { "tags": "or_query" } }, "must_not": { "terms": { "tags": "not_query" } } } } }
    compare_jsons(a, b)
  end

  #######
  #BLOCK#
  #######

  # def test_single_query_3
  #   a = @builder
  #       .query('nested', 'path', 'obj1') do |q|
  #         q.query('match', 'obj1.color', 'blue')
  #       end
  #       .build()
  #   b = { "query": { "nested": { "path": "obj1", "query": { "match": { "obj1.color": "blue" } } } } }
  #   compare_jsons(a, b)
  # end

  #################
  #WITH BASE QUERY#
  #################

  def test_base_query
    @builder.base_query = {
      query: {
        bool: {
        }
      }
    }
    a = @builder
        .query('match_all')
        .build()
    b = { "query": { "bool": { "must": { "match_all": {} } } } }
    compare_jsons(a, b)
  end

  # { multi_match: { query: @search, fuzziness: 'AUTO' } }
  # {constant_score: { filter: { terms: { id: integers } }, boost: 100 }}
  def test_base_query_2
    @builder.base_query = {
      query: {
        bool: {
        }
      }
    }
    a = @builder
        .query('bool') do |b|
          b.or_query('multi_match', { 'query': 'test', 'fuzziness': 'AUTO' })
          b.or_query('constant_score', { 'filter': { 'terms': { 'id': ['1'] } }, 'boost': 100 })
        end
        .build()
    b = { "query": { "bool": { "must": { "bool": { "should": [ { "multi_match": { "query": "test", "fuzziness": "AUTO" } }, { "constant_score": { "filter": { "terms": { "id": [ "1" ] } }, "boost": 100 } } ] } } } } }
    compare_jsons(a, b)
  end

  #####################
  #MULTI QUERY/FILTER #
  #####################

  def test_multi_0
    a = @builder
        .query('match_all')
        .filter('term', 'user', 'kimchy')
        .build()
    b = { "query": { "bool": { "filter": { "term": { "user": "kimchy" } }, "must": { "match_all": {} } } } }
    compare_jsons(a, b)
  end

  def test_multi_1
    a = @builder
        .filter('terms', 'tags', ['Emerging'])
        .filter('terms', 'tags', ['asdf'])
        .build
    b = { "query": { "bool": { "filter": [ { "terms": { "tags": [ "Emerging" ] } }, { "terms": { "tags": [ "asdf" ] } } ] } } }
    compare_jsons(a, b)
  end

  def test_multi_2
    a = @builder
        .query('exists', 'user')
        .or_query('term', 'user', 'kimchy')
        .build()
    b = { "query": { "bool": { "must": { "exists": { "field": "user" } }, "should": { "term": { "user": "kimchy" } } } } }
    compare_jsons(a, b)
  end

  def test_multi_3
    a = @builder
        .or_query('term', 'user', 'kimchy')
        .or_query('term', 'user', 'kimchy2')
        .build()
    b = { "query": { "bool": { "should": [ { "term": { "user": "kimchy" } }, { "term": { "user": "kimchy2" } } ] } } }
    compare_jsons(a, b)
  end

  def test_multi_4
    a = @builder
		    .query('exists', 'user')
        .or_query('term', 'user', 'kimchy')
		    .not_query('term', 'user', 'kimchy')
        .build()
    b = { "query": { "bool": { "must": { "exists": { "field": "user" } }, "should": { "term": { "user": "kimchy" } } , "must_not": { "term": { "user": "kimchy" } } } } }
    compare_jsons(a, b)
  end

  def test_multi_5
    a = @builder
        .filter('exists', 'user')
        .or_filter('term', 'user', 'kimchy')
        .build()
    b = { "query": { "bool": { "filter": { "bool": { "must": { "exists": { "field": "user" } }, "should": { "term": { "user": "kimchy" } } } } } } }
    compare_jsons(a, b)
  end

  def test_multi_6
    a = @builder
        .filter('exists', 'user')
        .or_filter('term', 'user', 'kimchy')
        .not_filter('term', 'user', 'kimchy')
        .build()
    b = { "query": { "bool": { "filter": { "bool": { "must": { "exists": { "field": "user" } }, "should": { "term": { "user": "kimchy" } }, "must_not": { "term": { "user": "kimchy" } } } } } } }
    compare_jsons(a, b)
  end

  def test_multi_7
    a = @builder
        .filter('term', 'filter')
        .or_filter('term', 'or_filter')
        .not_filter('term', 'not_filter')
        .query('term', 'query')
        .or_query('term', 'or_query')
        .not_query('term', 'not_query')
        .build()
    b = { "query": { "bool": { "filter": { "bool": { "must": { "term": { "field": "filter" } }, "should": { "term": { "field": "or_filter" } }, "must_not": { "term": { "field": "not_filter" } } } }, "must": { "term": { "field": "query" } }, "should": { "term": { "field": "or_query" } }, "must_not": { "term": { "field": "not_query" } } } } }
    compare_jsons(a, b)
  end

  def test_multi_8
    a = @builder
        .filter('term', 'filter')
        .or_filter('term', 'or_filter')
        .not_filter('term', 'not_filter')
        .query('term', 'query')
        .or_query('term', 'or_query')
        .not_query('term', 'not_query')
        .filter('term', 'filter_2')
        .or_filter('term', 'or_filter_2')
        .not_filter('term', 'not_filter_2')
        .query('term', 'query_2')
        .or_query('term', 'or_query_2')
        .not_query('term', 'not_query_2')
        .build()
    b = { "query": { "bool": { "filter": { "bool": { "must": [ { "term": { "field": "filter" } }, { "term": { "field": "filter_2" } } ], "should": [ { "term": { "field": "or_filter" } }, { "term": { "field": "or_filter_2" } } ], "must_not": [ { "term": { "field": "not_filter" } }, { "term": { "field": "not_filter_2" } } ] } }, "must": [ { "term": { "field": "query" } }, { "term": { "field": "query_2" } } ], "should": [ { "term": { "field": "or_query" } }, { "term": { "field": "or_query_2" } } ], "must_not": [ { "term": { "field": "not_query" } }, { "term": { "field": "not_query_2" } } ] } } }
    compare_jsons(a, b)
  end

  def test_multi_9
    a = @builder.query('nested', 'path', 'obj1', {score_mode: 'avg'}) do |q|
          q.query('match', 'obj1.name', 'blue')
          q.query('range', 'obj1.count', {gt: 5})
        end.build()
    b = { "query": { "nested": { "path": "obj1", "score_mode": "avg", "query": { "bool": { "must": [ { "match": { "obj1.name": "blue" } }, { "range": { "obj1.count": { "gt": 5 } } } ] } } } } }
    compare_jsons(a, b)
  end

  def test_multi_10
    a = @builder.query('a_key') do |q|
          q.query('nice', 'wow')
        end.build()
    b = { "query": { "a_key": { "query": { "nice": { "field": "wow" } } } } }
    compare_jsons(a, b)
  end

  def test_multi_11
    a = @builder
      .or_filter('bool') do |f|
          f.filter('terms', 'tags', ['Popular'])
          f.filter('terms', 'brands', ['A', 'B'])
          f.or_filter('bool') do |f|
            f.filter('terms', 'tags', ['Emerging'])
            f.filter('terms', 'brands', ['C'])
        end
      end
      .or_filter('bool') do |f|
          f.filter('terms', 'tags', ['Rumor'])
          f.filter('terms', 'companies', ['A', 'C', 'D'])
      end
      .build()
    b = { "query": { "bool": { "filter": { "bool": { "should": [ { "bool": { "must": [ { "terms": { "tags": [ "Popular" ] } }, { "terms": { "brands": [ "A", "B" ] } } ], "should": { "bool": { "filter": [ { "terms": { "tags": [ "Emerging" ] } }, { "terms": { "brands": [ "C" ] } } ] } } } }, { "bool": { "filter": [ { "terms": { "tags": [ "Rumor" ] } }, { "terms": { "companies": [ "A", "C", "D" ] } } ] } } ] } } } } }
    compare_jsons(a, b)
  end

end