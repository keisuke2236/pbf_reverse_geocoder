# frozen_string_literal: true

require 'pbf_reverse_geocoder'

RSpec.configure do |config|
  # rspec-expectations の設定
  config.expect_with :rspec do |expectations|
    # デフォルトの `should` 構文を無効化し、`expect` 構文のみ使用
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks の設定
  config.mock_with :rspec do |mocks|
    # 実際に存在するメソッドのみモックを許可
    mocks.verify_partial_doubles = true
  end

  # 実行するテストをランダム化して依存関係を検出
  config.order = :random
  Kernel.srand config.seed

  # 共有コンテキストのメタデータを利用可能にする
  config.shared_context_metadata_behavior = :apply_to_host_groups
end
