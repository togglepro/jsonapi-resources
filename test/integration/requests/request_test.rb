require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class RequestTest < ActionDispatch::IntegrationTest
  def test_get
    get '/posts', nil, 'Accept' => Mime::JSONAPI
    assert_equal 200, status
  end

  # ToDo: fix this test. The posts param is not making it in if the headers are set
  # def test_put_single
  #   put '/posts/3', {"posts" => {"id" => "3", "title" => "A great new Post", "links" => { "tags" => [3,4] }}},
  #       'Content-Type' => Mime::JSONAPI, 'Accept' => Mime::JSONAPI
  #   assert_equal 200, status
  # end

  def test_destroy_single
    delete '/posts/7', nil, 'Accept' => Mime::JSONAPI
    assert_equal 204, status
  end

  def test_destroy_multiple
    delete '/posts/8,9', nil, 'Accept' => Mime::JSONAPI
    assert_equal 204, status
  end
end
