require 'timeout'
module Gitlab
  module Git
    class Compare
      TIME_OUT_TIME = 240
      attr_reader :same, :timeout_diffs, :timeout_commits, :head, :base, :repo_path

      def initialize(repository, base, head)
        @same = false
        @repo_path = repository.path
        @timeout_diffs = false
        @timeout_commits = false

        @base = Gitlab::Git::Commit.find(repository, base)
        @head = Gitlab::Git::Commit.find(repository, head)

        return unless @base && @head

        if @base.id == @head.id
          @same = true
        end
      end

      def commits(options={})
        return [] if @same || @base.nil? || @head.nil?

        begin
          ::Timeout.timeout(TIME_OUT_TIME) do
            @commits = Gitlab::Git::Commit.between_rpc(repository, @base.id, @head.id, options)
          end
        rescue ::Timeout::Error => ex
          @commits = []
          @timeout_commits = true
        end
        @commits
      end

      def diffs(paths = nil, options={})
        return [] if @same || @base.nil? || @head.nil?
        return @diffs,@diffs_size unless @diffs.nil?

        # Try to collect diff only if diffs is empty
        # Otherwise return cached version
        begin
          ::Timeout.timeout(TIME_OUT_TIME) do
            @diffs, @diffs_size= Gitlab::Git::Diff.between_with_size(repository, @head.id, @base.id, options, *paths)
          end
        rescue ::Timeout::Error => ex
          @diffs = []
          @timeout_diffs = true
        end
        return @diffs, @diffs_size
      end

      def repository
        Gitlab::Git::Repository.new @repo_path
      end

      def empty_diff?
        diffs.first.empty? && timeout_diffs == false
      end

    end
  end
end
