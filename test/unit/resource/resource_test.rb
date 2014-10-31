require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class ArticleResource < JSONAPI::Resource
  model_name 'Post'
end

class CatResource < JSONAPI::Resource
  attribute :id
  attribute :name
  attribute :breed

  has_one :mother, class_name: 'Cat'
  has_one :father, class_name: 'Cat'
end

class ResourceTest < MiniTest::Unit::TestCase
  def setup
    @post = Post.first
  end

  def test_model_name
    assert_equal(PostResource._model_name, 'Post')
  end

  def test_model
    assert_equal(PostResource._model_class, Post)
  end

  def test_model_alternate
    assert_equal(ArticleResource._model_class, Post)
  end

  def test_class_attributes
    attrs = CatResource._attributes
    assert_kind_of(Hash, attrs)
    assert_equal(attrs.keys.size, 3)
  end

  def test_class_assosications
    associations = CatResource._associations
    assert_kind_of(Hash, associations)
    assert_equal(associations.size, 2)
  end

  def test_links_href
    links = CatResource._links(link_format: :href, base_url: 'http://test')
    expected_links = {
      'cats.mother' => 'http://test/cats/{cats.mother}',
      'cats.father' => 'http://test/cats/{cats.father}',
    }

    assert_hash_equals(expected_links, links)
  end

  def test_links_full
    links = CatResource._links(link_format: :full, base_url: 'http://test')
    expected_links = {
      'cats.mother' => {
        href: 'http://test/cats/{cats.mother}',
        type: 'cats'
      },
      'cats.father' => {
        href: 'http://test/cats/{cats.father}',
        type: 'cats'
      }
    }

    assert_hash_equals(expected_links, links)
  end

  def test_links_none
    links = CatResource._links(link_format: :none, base_url: 'http://test')

    assert_nil(links)
  end

end
