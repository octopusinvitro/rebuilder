require 'test_helper'

ChildStatus = Struct.new(:success?)

describe RebuilderJob do
  class RebuilderJob
    def with_git_repo(_repo, _options, &block)
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('data/Australia/Senate')
          block.call(dir)
        end
      end
    end

    def run(*_args)
      ['Build output', ChildStatus.new(true)]
    end
  end

  around { |test| VCR.use_cassette('countries_json', &test) }

  it 'rebuilds the selected source' do
    RebuilderJob.new.perform('Australia', 'Senate')
    assert_equal 1, CreatePullRequestJob.jobs.size
    args = CreatePullRequestJob.jobs.first['args']
    assert args[0].match(/australia-senate-\d+/)
    assert_equal 'Australia (Senate): refresh data', args[1]
    expected = <<-EXPECTED.chomp
Automated data refresh for Australia - Senate

#### Output

```
Build output
```
    EXPECTED
    assert_equal expected, Sidekiq.redis { |conn| conn.get("body:#{args[0]}") }
    Sidekiq.redis { |conn| conn.del("body:#{args[0]}") }
  end
end
