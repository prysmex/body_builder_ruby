# frozen_string_literal: true

require 'test_helper'

module BuilderTestMethods
  def setup
    @builder = BodyBuilder::Builder.new
  end
end

class HelperTest < Minitest::Test

  include BuilderTestMethods

  def compare_jsons(value, expected)
    assert_equal value, expected
  end

  def test_respond_to_methods
    # query
    assert_respond_to @builder, :query
    assert_respond_to @builder, :and_query
    assert_respond_to @builder, :or_query
    assert_respond_to @builder, :not_query

    # filter
    assert_respond_to @builder, :filter
    assert_respond_to @builder, :and_filter
    assert_respond_to @builder, :or_filter
    assert_respond_to @builder, :not_filter

    # other
    assert_respond_to @builder, :base_query
    assert_respond_to @builder, :raw_option
    assert_respond_to @builder, :sort_field

    assert_respond_to @builder, :queries?
    assert_respond_to @builder, :filters?

    assert_respond_to @builder, :reset!
    assert_respond_to @builder, :reset_queries!
    assert_respond_to @builder, :reset_filters!
    assert_respond_to @builder, :reset_raw_options!
    assert_respond_to @builder, :reset_sort_fields!
  end

  def test_size
    a = @builder
      .set_size(5)
      .build
    b = { size: 5 }
    compare_jsons(a, b)
  end

  def test_from
    a = @builder
      .set_from(50)
      .build
    b = { from: 50 }
    compare_jsons(a, b)
  end

  def test_raw_option
    a = @builder
      .raw_option(:size, 5)
      .build
    b = { size: 5 }
    compare_jsons(a, b)
  end

  def test_sort_field
    a = @builder
      .sort_field(:id, 'desc')
      .build
    b = { sort: [{id: 'desc'}] }
    compare_jsons(a, b)
  end

  def test_override_sort_field
    a = @builder
      .sort_field(:id, 'desc')
      .sort_field(:id, 'asc')
      .build
    b = { sort: [{id: 'asc'}] }
    compare_jsons(a, b)
  end

  def test_queries?
    assert_equal false, @builder.queries?
    @builder.filter('match_all')

    assert_equal false, @builder.queries?
    @builder.query('match_all')

    assert_equal true, @builder.queries?
  end

  def test_filters?
    assert_equal false, @builder.filters?
    @builder.query('match_all')

    assert_equal false, @builder.filters?
    @builder.filter('match_all')

    assert_equal true, @builder.filters?
  end

  def test_reset_queries!
    @builder.query('match_all')
    @builder.reset_queries!

    assert_equal false, @builder.queries?
  end

  def test_reset_filters!
    @builder.filter('match_all')
    @builder.reset_filters!

    assert_equal false, @builder.filters?
  end

  def test_reset_raw_options!
    @builder.raw_option('size', 10)

    assert_equal 1, @builder.raw_options.size
    @builder.reset_raw_options!

    assert_empty @builder.raw_options
  end

  def test_reset_sort_fields!
    @builder.sort_field('id', 'asc')

    assert_equal 1, @builder.sort_fields.size
    @builder.reset_sort_fields!

    assert_empty @builder.sort_fields
  end

  # def test_reset!
  # end

  ########
  # ARGS #
  ########

  def test_single_query_1_arg
    a = @builder
      .query('match_all')
      .build
    b = { query: { match_all: {} } }
    compare_jsons(a, b)
  end

  def test_single_query_2_args
    a = @builder
      .query('exists', 'user')
      .build
    b = { query: { exists: { field: 'user' } } }
    compare_jsons(a, b)
  end

  def test_single_query_3_args
    a = @builder
      .query('range', 'date', {gt: 'now-1d'})
      .build
    b = { query: { range: { date: { gt: 'now-1d' } } } }
    compare_jsons(a, b)
  end

  def test_single_query_4_args
    a = @builder
      .query('geo_distance', 'point', {lat: 40, lon: 20}, {distance: '12km'})
      .build
    b = {
      query: {
        geo_distance: { point: { lat: 40, lon: 20 }, distance: '12km' }
      }
    }
    compare_jsons(a, b)
  end

  ###########
  # FILTERS #
  ###########

  # SINGLES

  def test_single_filter_boolean
    a = @builder
      .filter('term', 'active', false)
      .build
    b = { query: { bool: { filter: { term: { active: false } } } } }
    compare_jsons(a, b)
  end

  def test_single_filter
    a = @builder
      .filter('terms', 'tags', ['Emerging'])
      .build
    b = { query: { bool: { filter: { terms: { tags: ['Emerging'] } } } } }
    compare_jsons(a, b)
  end

  def test_single_and_filter
    a = @builder
      .and_filter('terms', 'tags', ['Emerging'])
      .build
    b = { query: { bool: { filter: { terms: { tags: ['Emerging'] } } } } }
    compare_jsons(a, b)
  end

  def test_single_or_filter
    a = @builder
      .or_filter('terms', 'tags', ['Emerging'])
      .build
    b = {
      query: {
        bool: {
          filter: { bool: { should: { terms: { tags: ['Emerging'] } } } }
        }
      }
    }
    compare_jsons(a, b)
  end

  def test_single_not_filter
    a = @builder
      .not_filter('terms', 'tags', ['Emerging'])
      .build
    b = { query: { bool: { must_not: { terms: { tags: ['Emerging'] } } } } }
    compare_jsons(a, b)
  end

  # COMBINED

  def test_all_filters
    a = @builder
      .filter('terms', 'tags', 'filter')
      .or_filter('terms', 'tags', 'or_filter')
      .not_filter('terms', 'tags', 'not_filter')
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              must: { terms: { tags: 'filter' } },
              should: { terms: { tags: 'or_filter' } },
              must_not: { terms: { tags: 'not_filter' } }
            }
          }
        }
      }
    }
    compare_jsons(a, b)
  end

  def test_repeated_filters
    a = @builder
      .filter('terms', 'tags', 'filter')
      .filter('terms', 'tags', 'filter')
      .or_filter('terms', 'tags', 'or_filter')
      .or_filter('terms', 'tags', 'or_filter')
      .not_filter('terms', 'tags', 'not_filter')
      .not_filter('terms', 'tags', 'not_filter')
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              must: [
                { terms: { tags: 'filter' } },
                { terms: { tags: 'filter' } }
              ],
              should: [
                { terms: { tags: 'or_filter' } },
                { terms: { tags: 'or_filter' } }
              ],
              must_not: [
                { terms: { tags: 'not_filter' } },
                { terms: { tags: 'not_filter' } }
              ]
            }
          }
        }
      }
    }
    compare_jsons(a, b)
  end

  # Block

  def test_all_filter_blocks
    a = @builder
      .filter('bool') do |f|
        f.filter('match', 'message', 'filter')
      end
      .not_filter('bool') do |f|
        f.filter('match', 'message', 'not_filter')
      end
      .or_filter('bool') do |f|
        f.filter('match', 'message', 'or_filter')
      end
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              must: {
                bool: { filter: { match: { message: 'filter' } } }
              },
              should: {
                bool: { filter: { match: { message: 'or_filter' } } }
              },
              must_not: {
                bool: { filter: { match: { message: 'not_filter' } } }
              }
            }
          }
        }
      }
    }

    compare_jsons(a, b)
  end

  def test_all_filter_blocks_double
    a = @builder
      .filter('bool') do |f|
        f.filter('match', 'message', 'filter')
        f.filter('match', 'message', 'filter')
      end
      .not_filter('bool') do |f|
        f.filter('match', 'message', 'not_filter')
        f.filter('match', 'message', 'not_filter')
      end
      .or_filter('bool') do |f|
        f.filter('match', 'message', 'or_filter')
        f.filter('match', 'message', 'or_filter')
      end
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              must: {
                bool: { filter: [{ match: { message: 'filter' } }, { match: { message: 'filter' } }] }
              },
              should: {
                bool: { filter: [{ match: { message: 'or_filter' } }, { match: { message: 'or_filter' } }] }
              },
              must_not: {
                bool: { filter: [{ match: { message: 'not_filter' } }, { match: { message: 'not_filter' } }] }
              }
            }
          }
        }
      }
    }

    compare_jsons(a, b)
  end

  def test_all_filter_blocks_nested
    a = @builder
      .filter('bool') do |f|
        f.filter('match', 'message', 'filter')
        f.not_filter('bool') do |f|
          f.filter('match', 'message', 'not_filter')
          f.or_filter('bool') do |f|
            f.filter('match', 'message', 'or_filter')
          end
        end
      end
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              must: { match: { message: 'filter' } },
              must_not: {
                bool: {
                  must: { match: { message: 'not_filter' } },
                  should: {
                    bool: { filter: { match: { message: 'or_filter' } } }
                  }
                }
              }
            }
          }
        }
      }
    }

    compare_jsons(a, b)
  end

  #########
  # QUERY #
  #########

  # SINGLES

  def test_single_query
    a = @builder
      .query('match', 'tags', 'Emerging')
      .build
    b = { query: { match: { tags: 'Emerging' } } }
    compare_jsons(a, b)
  end

  def test_single_and_query
    a = @builder
      .query('match', 'tags', 'Emerging')
      .build
    b = { query: { match: { tags: 'Emerging' } } }
    compare_jsons(a, b)
  end

  def test_single_or_query
    a = @builder
      .or_query('terms', 'tags', ['Emerging'])
      .build
    b = { query: { bool: { should: { terms: { tags: ['Emerging'] } } } } }
    compare_jsons(a, b)
  end

  def test_single_not_query
    a = @builder
      .not_query('terms', 'tags', ['Emerging'])
      .build
    b = { query: { bool: { must_not: { terms: { tags: ['Emerging'] } } } } }
    compare_jsons(a, b)
  end

  # COMBINED

  def test_all_querys
    a = @builder
      .query('terms', 'tags', 'query')
      .or_query('terms', 'tags', 'or_query')
      .not_query('terms', 'tags', 'not_query')
      .build
    b = {
      query: {
        bool: {
          must: { terms: { tags: 'query' } },
          should: { terms: { tags: 'or_query' } },
          must_not: { terms: { tags: 'not_query' } }
        }
      }
    }
    compare_jsons(a, b)
  end

  def test_repeated_queries
    a = @builder
      .query('terms', 'tags', 'query')
      .query('terms', 'tags', 'query')
      .or_query('terms', 'tags', 'or_query')
      .or_query('terms', 'tags', 'or_query')
      .not_query('terms', 'tags', 'not_query')
      .not_query('terms', 'tags', 'not_query')
      .build
    b = {
      query: {
        bool: {
          must: [
            { terms: { tags: 'query' } },
            { terms: { tags: 'query' } }
          ],
          should: [
            { terms: { tags: 'or_query' } },
            { terms: { tags: 'or_query' } }
          ],
          must_not: [
            { terms: { tags: 'not_query' } },
            { terms: { tags: 'not_query' } }
          ]
        }
      }
    }
    compare_jsons(a, b)
  end

  #########
  # BLOCK #
  #########

  def test_all_query_blocks
    a = @builder
      .query('bool') do |f|
        f.query('match', 'message', 'query')
      end
      .not_query('bool') do |f|
        f.query('match', 'message', 'not_query')
      end
      .or_query('bool') do |f|
        f.query('match', 'message', 'or_query')
      end
      .build
    b = {
      query: {
        bool: {
          must: { bool: { must: { match: { message: 'query' } } } },
          should: { bool: { must: { match: { message: 'or_query' } } } },
          must_not: {
            bool: { must: { match: { message: 'not_query' } } }
          }
        }
      }
    }
    compare_jsons(a, b)
  end

  def test_all_query_blocks_double
    a = @builder
      .query('bool') do |f|
        f.query('match', 'message', 'query')
        f.query('match', 'message', 'query')
      end
      .not_query('bool') do |f|
        f.query('match', 'message', 'not_query')
        f.query('match', 'message', 'not_query')
      end
      .or_query('bool') do |f|
        f.query('match', 'message', 'or_query')
        f.query('match', 'message', 'or_query')
      end
      .build
    b = {
      query: {
        bool: {
          must: {
            bool: {
              must: [
                { match: { message: 'query' } },
                { match: { message: 'query' } }
              ]
            }
          },
          should: {
            bool: {
              must: [
                { match: { message: 'or_query' } },
                { match: { message: 'or_query' } }
              ]
            }
          },
          must_not: {
            bool: {
              must: [
                { match: { message: 'not_query' } },
                { match: { message: 'not_query' } }
              ]
            }
          }
        }
      }
    }

    compare_jsons(a, b)
  end

  def test_all_query_blocks_nested
    a = @builder
      .query('bool') do |f|
        f.query('match', 'message', 'query')
        f.not_query('bool') do |f|
          f.query('match', 'message', 'not_query')
          f.or_query('bool') do |f|
            f.query('match', 'message', 'or_query')
          end
        end
      end
      .build
    b = {
      query: {
        bool: {
          must: { match: { message: 'query' } },
          must_not: {
            bool: {
              must: { match: { message: 'not_query' } },
              should: {
                bool: { must: { match: { message: 'or_query' } } }
              }
            }
          }
        }
      }
    }

    compare_jsons(a, b)
  end

  def test_query_block_1
    a = @builder
      .query('bool') do |f|
        f.query('term', 'field1', 1)
        f.query('term', 'field2', 2)
        f.or_query('term', 'field3', 3)
      end
      .query('bool') do |f|
        f.query('term', 'field4', 10)
        f.query('term', 'field5', 20)
        f.or_query('term', 'field6', 30)
      end
      .build

    b = {
      query: {
        bool: {
          must: [
            {
              bool: {
                must: [{ term: { field1: 1 } }, { term: { field2: 2 } }],
                should: { term: { field3: 3 } }
              }
            },
            {
              bool: {
                must: [
                  { term: { field4: 10 } },
                  { term: { field5: 20 } }
                ],
                should: { term: { field6: 30 } }
              }
            }
          ]
        }
      }
    }
    compare_jsons(a, b)
  end

  ###################
  # WITH BASE QUERY #
  ###################

  def test_base_query
    @builder.base_query = {
      query: {
        bool: {
        }
      }
    }
    a = @builder
      .query('match_all')
      .build
    b = { query: { bool: { must: { match_all: {} } } } }
    compare_jsons(a, b)
  end

  def test_base_query_2
    @builder.base_query = {
      query: {
        bool: {
        }
      }
    }
    a = @builder
      .query('bool') do |b|
        b.or_query('multi_match', { query: 'test', fuzziness: 'AUTO' })
        b.or_query('constant_score', { filter: { terms: { id: ['1'] } }, boost: 100 })
      end
      .build
    b = {
      query: {
        bool: {
          must: {
            bool: {
              should: [
                { multi_match: { query: 'test', fuzziness: 'AUTO' } },
                {
                  constant_score: {
                    filter: { terms: { id: ['1'] } },
                    boost: 100
                  }
                }
              ]
            }
          }
        }
      }
    }
    compare_jsons(a, b)
  end

  #########################
  # COMBINED QUERY/FILTER #
  #########################

  def test_multi_0
    a = @builder
      .query('match_all')
      .filter('term', 'user', 'kimchy')
      .build
    b = {
      query: {
        bool: {
          filter: { term: { user: 'kimchy' } },
          must: { match_all: {} }
        }
      }
    }
    compare_jsons(a, b)
  end

  def test_multi_1
    a = @builder
      .filter('term', 'filter')
      .or_filter('term', 'or_filter')
      .not_filter('term', 'not_filter')
      .query('term', 'query')
      .or_query('term', 'or_query')
      .not_query('term', 'not_query')
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              must: { term: { field: 'filter' } },
              should: { term: { field: 'or_filter' } },
              must_not: { term: { field: 'not_filter' } }
            }
          },
          must: { term: { field: 'query' } },
          should: { term: { field: 'or_query' } },
          must_not: { term: { field: 'not_query' } }
        }
      }
    }
    compare_jsons(a, b)
  end

  def test_multi_2
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
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              must: [
                { term: { field: 'filter' } },
                { term: { field: 'filter_2' } }
              ],
              should: [
                { term: { field: 'or_filter' } },
                { term: { field: 'or_filter_2' } }
              ],
              must_not: [
                { term: { field: 'not_filter' } },
                { term: { field: 'not_filter_2' } }
              ]
            }
          },
          must: [
            { term: { field: 'query' } },
            { term: { field: 'query_2' } }
          ],
          should: [
            { term: { field: 'or_query' } },
            { term: { field: 'or_query_2' } }
          ],
          must_not: [
            { term: { field: 'not_query' } },
            { term: { field: 'not_query_2' } }
          ]
        }
      }
    }
    compare_jsons(a, b)
  end

  def test_multi_3
    a = @builder.query('nested', 'path', 'obj1', {score_mode: 'avg'}) do |q|
      q.query('match', 'obj1.name', 'blue')
      q.query('range', 'obj1.count', {gt: 5})
    end.build
    b = {
      query: {
        nested: {
          path: 'obj1',
          score_mode: 'avg',
          query: {
            bool: {
              must: [
                { match: { 'obj1.name': 'blue' } },
                { range: { 'obj1.count': { gt: 5 } } }
              ]
            }
          }
        }
      }
    }
    compare_jsons(a, b)
  end

  # def test_multi_4
  #   a = @builder.query('a_key') do |q|
  #         q.query('nice', 'wow')
  #       end.build()
  #   b = { "query": { "a_key": { "query": { "nice": { "field": "wow" } } } } }
  #   compare_jsons(a, b)
  # end

  def test_multi_5
    a = @builder
      .or_filter('bool') do |f|
        f.filter('terms', 'tags', ['Popular'])
        f.filter('terms', 'brands', %w[A B])
        f.or_filter('bool') do |f|
          f.filter('terms', 'tags', ['Emerging'])
          f.filter('terms', 'brands', ['C'])
        end
      end
      .or_filter('bool') do |f|
        f.filter('terms', 'tags', ['Rumor'])
        f.filter('terms', 'companies', %w[A C D])
      end
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              should: [
                {
                  bool: {
                    must: [
                      { terms: { tags: ['Popular'] } },
                      { terms: { brands: %w[A B] } }
                    ],
                    should: {
                      bool: {
                        filter: [
                          { terms: { tags: ['Emerging'] } },
                          { terms: { brands: ['C'] } }
                        ]
                      }
                    }
                  }
                },
                {
                  bool: {
                    filter: [
                      { terms: { tags: ['Rumor'] } },
                      { terms: { companies: %w[A C D] } }
                    ]
                  }
                }
              ]
            }
          }
        }
      }
    }
    compare_jsons(a, b)
  end

  def test_multi_6
    assert_raises(StandardError) {
      @builder.filter('bool') do |f|
        f.query('match', 'message', 'this is a test')
      end.build
    }
  end

  def test_multi_8
    a = @builder
      .query('bool') do |q|
        q.filter('term', 'message', 'asdf')
      end
      .build
    b = { query: { bool: { filter: { term: { message: 'asdf' } } } } }
    compare_jsons(a, b)
  end

  def test_multi_9
    a = @builder
      .query('bool') do |q|
        q.or_filter('term', 'message', 'asdf')
      end
      .build
    b = {
      query: {
        bool: {
          filter: { bool: { should: { term: { message: 'asdf' } } } }
        }
      }
    }

    compare_jsons(a, b)
  end

  # minimumShouldMatch

  def test_mimimum_should_match_1
    a = @builder
      .or_filter('term', 'state', 'one')
      .or_filter('term', 'state', 'two')
      .or_query('match', 'message', 'nice')
      .or_query('match', 'message', 'something')
      .set_query_minimum_should_match(2)
      .set_filter_minimum_should_match(3)
      .build
    b = {
      query: {
        bool: {
          filter: {
            bool: {
              should: [
                { term: { state: 'one' } },
                { term: { state: 'two' } }
              ],
              minimum_should_match: 3
            }
          },
          should: [
            { match: { message: 'nice' } },
            { match: { message: 'something' } }
          ],
          minimum_should_match: 2
        }
      }
    }

    compare_jsons(a, b)
  end

  def test_mimimum_should_match_2
    a = @builder
      .or_query('match', 'message', 'nice')
      .set_query_minimum_should_match(2)
      .build
    b = { query: { bool: { should: { match: { message: 'nice' } } } } }
    compare_jsons(a, b)
  end

  def test_mimimum_should_match_3
    a = @builder
      .or_query('match', 'message', 'nice')
      .set_query_minimum_should_match(1)
      .build
    b = { query: { bool: { should: { match: { message: 'nice' } } } } }
    compare_jsons(a, b)
  end

  def test_mimimum_should_match_4
    a = @builder.query('bool') do |b|
      b.or_query('match', 'message', 'test')
      b.or_query('match', 'message', 'something else')
      b.set_query_minimum_should_match(1)
    end.build
    b = {
      query: {
        bool: {
          should: [
            { match: { message: 'test' } },
            { match: { message: 'something else' } }
          ],
          minimum_should_match: 1
        }
      }
    }
    compare_jsons(a, b)
  end

end