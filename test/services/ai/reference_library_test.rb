require "test_helper"

class Ai::ReferenceLibraryTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join("test", "fixtures", "files", "reference_index")

  # The fixture's three chunks sit on the first three axes, so a query vector
  # picks its matches exactly. The embedder records what it was asked.
  def library(dir = FIXTURE, vector: [1, 0, 0, 0])
    @queries = []
    Ai::ReferenceLibrary.new(dir: dir, embedder: ->(texts) { @queries.concat(texts); [vector] })
  end

  test "available only when every index file exists" do
    assert library.available?
    assert_not library(Rails.root.join("tmp", "nowhere")).available?
  end

  test "an unbuilt library returns an error instead of raising" do
    result = library(Rails.root.join("tmp", "nowhere")).search("debt recycling")
    assert_match(/not been built/, result[:error])
  end

  test "returns the closest excerpt with its source, without the context line" do
    result = library.search("is debt recycling worth it", top_k: 1)

    assert_equal ["is debt recycling worth it"], @queries
    hit = result[:results].sole
    assert_equal "Aussie FIRE episode 19: 19. Debt recycling", hit[:source]
    assert_equal "podcast", hit[:kind]
    assert_equal "2024-08-16", hit[:date]
    assert_equal "https://example.com/aussie-fire/19", hit[:url]
    assert_equal 1.0, hit[:relevance]
    assert hit[:excerpt].start_with?("Debt recycling turns")
  end

  test "ranks by similarity and drops weak matches" do
    # Scores: super 0.73, debt recycling 0.61, book 0.30 (below MIN_SCORE).
    result = library(vector: [1, 1.2, 0.5, 0]).search("salary sacrifice", top_k: 5)

    assert_equal ["money money money: Salary sacrifice Q&A", "Aussie FIRE episode 19: 19. Debt recycling"],
                 result[:results].map { |r| r[:source] }
    assert result[:results].all? { |r| r[:relevance] >= Ai::ReferenceLibrary::MIN_SCORE }
  end

  test "slug episodes stay out of the label and sources without a title use the file name" do
    assert_equal "money money money: Salary sacrifice Q&A",
                 library(vector: [0, 1, 0, 0]).search("super", top_k: 1)[:results].sole[:source]

    book = library(vector: [0, 0, 1, 0]).search("etf fees", top_k: 1)[:results].sole
    assert_equal "a-book-about-etfs.pdf", book[:source]
    assert_nil book[:url]
  end

  test "nothing relevant gives an empty result list" do
    assert_empty library(vector: [0, 0, 0, 1]).search("pizza")[:results]
  end

  test "top_k is clamped to 1..MAX_RESULTS" do
    # Two chunks clear MIN_SCORE for this vector.
    assert_equal 1, library(vector: [1, 1.2, 0, 0]).search("x", top_k: 0)[:results].size
    assert_equal 2, library(vector: [1, 1.2, 0, 0]).search("x", top_k: "2")[:results].size
    assert_equal 2, library(vector: [1, 1.2, 0, 0]).search("x", top_k: 50)[:results].size
  end

  test "picks up a rebuilt index without a restart" do
    Dir.mktmpdir do |dir|
      FileUtils.cp_r("#{FIXTURE}/.", dir)
      lib = library(dir)
      assert_equal 3, lib.size

      File.write("#{dir}/meta.jsonl", File.readlines("#{dir}/meta.jsonl").first(2).join)
      File.binwrite("#{dir}/embeddings.bin", [1, 0, 0, 0, 0, 1, 0, 0].pack("e*"))
      later = 1.minute.from_now.to_time
      Ai::ReferenceLibrary::FILES.each { |f| File.utime(later, later, "#{dir}/#{f}") }

      assert_equal 2, lib.size
    end
  end

  test "an index with mismatched vectors and chunks is refused" do
    Dir.mktmpdir do |dir|
      FileUtils.cp_r("#{FIXTURE}/.", dir)
      File.binwrite("#{dir}/embeddings.bin", [1, 0, 0, 0].pack("e*"))
      assert_raises(RuntimeError) { library(dir).search("x") }
    end
  end
end
