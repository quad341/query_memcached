require File.dirname(__FILE__) + '/../test_helper'

class QueryCacheTest < Test::Unit::TestCase
  
  fixtures :tasks, :topics, :categories, :posts, :categories_posts
  
  def test_find_queries
    assert_queries(2) { Task.find(1); Task.find(1) }
  end

  def test_find_queries_with_query_memcache_enabled
    Computer.cache do
      assert_queries(1) { Computer.find(1); Computer.find(1) }
    end
  end

  def test_find_queries_with_cache
    Task.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    end
  end
  
  def test_count_queries_with_cache
    Task.cache do
      assert_queries(1) { Task.count; Task.count }
    end
  end
  
  def test_query_cache_dups_results_correctly
    Task.cache do
      now  = Time.now.utc
      task = Task.find 1
      assert_not_equal now, task.starting
      task.starting = now
      task.reload
      assert_not_equal now, task.starting
    end
  end
  
  def test_cache_is_flat
    Task.cache do
      Topic.columns # don't count this query
      assert_queries(1) { Topic.find(1); Topic.find(1); }
    end
  
    ActiveRecord::Base.cache do
      assert_queries(1) { Task.find(1); Task.find(1) }
    end
  end
  
  def test_cache_does_not_wrap_string_results_in_arrays
    Task.cache do
      assert_instance_of String, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
    end
  end

  def test_cache_uses_proper_marshaling
     User.connection_with_memcache_query_cache.stubs(:query_key).returns('marshal/known_key')
     User.connection_with_memcache_query_cache.stubs(:memcache_query_cache_options).returns({})
     User.cache do
       u = User.find(1)
       expected_str = "\004\b[\006{\035\"\rrealm_id\"\0061\"\021work_country\"\aUS\"\022manager_valid\"\0061\"\017created_at\"\0302009-06-14 12:00:00\"\ntitle\"\034annoying show character\"\017updated_at\"\0302009-06-14 12:00:00\"\026materialized_path\"\t001.\"\017manager_id\"\0061\"\nim_id\"\022bobthebuilder\"\rusername\"\017bobbuilder\"\017created_by\"\0061\"\fenabled\"\0061\"\020employee_id\"\a12\"\aid\"\0061\"\021phone_number\"\0231-800-555-5555\"\017updated_by\"\0061\"\016full_name\"\024bob the builder\"\016last_name\"\fbuilder\"\023picture_exists\"\0060\"\026acting_manager_id\"\0063\"\025manager_username\"\btom\"\nemail\"\024bob@builder.com\"\020middle_name\"\bthe\"\017first_name\"\bbob"
       assert_equal expected_str, ::Rails.cache.read('marshal/known_key')
     end
  end
end

uses_mocha 'QueryCacheExpiryTest' do

class QueryCacheExpiryTest < Test::Unit::TestCase
  fixtures :tasks
  
  def setup
    ::Rails.cache.clear
  end

  def test_find
    Task.connection.expects(:clear_query_cache).times(1)

    assert !Task.connection.query_cache_enabled
    Task.cache do
      assert Task.connection.query_cache_enabled
      Task.find(1)

      Task.uncached do
        assert !Task.connection.query_cache_enabled
        Task.find(1)
      end

      assert Task.connection.query_cache_enabled
    end
    assert !Task.connection.query_cache_enabled
  end

  def test_find_without_query_memcached_activated
    ::Rails.cache.expects(:write).times(0)
    ::Rails.cache.expects(:read).times(0)
    Task.cache do
      Task.find(1)
      Task.find(1)
    end
  end
  
  def test_find_with_query_memcached_activated
    # 3 writes:
    # - version
    # - version/computers
    # - version/computers/1
    ::Rails.cache.expects(:write).times(3)
    # The same reads
    ::Rails.cache.expects(:read).times(3)
    Computer.cache do
      Computer.find(1)
      Computer.find(1)
    end
  end

  def test_update
    Task.connection.expects(:clear_query_cache).times(2)

    Task.cache do
      task = Task.find(1)
      task.starting = Time.now.utc
      task.save!
    end
  end
  
  def test_update_model_with_query_memcached_should_update_key
    version = ::Rails.cache.read('version/computers') || 0
    Computer.cache do
      computer = Computer.find(1)
      computer.developer = Developer.find(2)
      computer.save!
    end
    assert_equal version + 1, ::Rails.cache.read('version/computers')
  end
  

  def test_destroy
    Task.connection.expects(:clear_query_cache).times(2)

    Task.cache do
      Task.find(1).destroy
    end
  end

  def test_destroy_model_with_query_memcached_should_update_key
    version = ::Rails.cache.read('version/computers') || 0
    Computer.cache do
      Computer.find(1).destroy
    end
    assert_equal version + 1, ::Rails.cache.read('version/computers')
  end

  def test_insert
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)

    Task.cache do
      Task.create!
    end
  end
  
  def test_insert_model_with_query_memcached_should_update_key
    version = ::Rails.cache.read('version/computers') || 0
    Computer.cache do
      Computer.create!(:developer => Developer.find(1), :extendedWarranty => 1)
    end
    assert_equal version + 1, ::Rails.cache.read('version/computers')
  end

  def test_cache_is_expired_by_habtm_update
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)
    ActiveRecord::Base.cache do
      c = Category.find(:first)
      p = Post.find(:first)
      p.categories << c
    end
  end

  def test_cache_is_expired_by_habtm_delete
    ActiveRecord::Base.connection.expects(:clear_query_cache).times(2)
    ActiveRecord::Base.cache do
      c = Category.find(:first)
      p = Post.find(:first)
      p.categories.delete_all
    end
  end
end

end
