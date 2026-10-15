# Semantic search over the reference library built by the sibling
# fire-adviser-training repo (ruby rag/embed.rb): podcast transcripts and
# books, chunked and embedded with nomic-embed-text.
#
# The index is read in place from that repo's rag/index/ — the excerpts are
# copyrighted, so they are never copied into this repo — and held in memory.
# 7.6k chunks score in well under 100ms in plain Ruby, so there is no vector
# database. A rebuilt index is picked up on the next search.
module Ai
  class ReferenceLibrary
    FILES = %w[info.json embeddings.bin meta.jsonl].freeze
    MAX_RESULTS = 5
    # Finance questions score 0.65+ against relevant excerpts; unrelated ones stay
    # under ~0.56 ("best pizza in melbourne" tops out there).
    MIN_SCORE = 0.6

    def self.default
      # An unset config.x key is an empty OrderedOptions, not nil, hence presence.
      @default ||= new(dir: Rails.configuration.x.reference_index_dir.presence ||
                            ENV.fetch("REFERENCE_INDEX_DIR",
                                      Rails.root.join("..", "fire-adviser-training", "rag", "index")))
    end

    # embedder takes an array of strings and returns one vector per string.
    def initialize(dir:, embedder: ->(texts) { OllamaService.new.embed(texts) })
      @dir = Pathname(dir)
      @embedder = embedder
      @lock = Mutex.new
    end

    def available?
      FILES.all? { |f| @dir.join(f).file? }
    end

    def size
      index[:meta].size
    end

    def search(query, top_k: 3)
      return { error: "The reference library has not been built yet." } unless available?

      top_k = top_k.to_i.clamp(1, MAX_RESULTS)
      vector = normalise(@embedder.call([query]).first)
      data = index

      scored = data[:rows].each_with_index.map { |row, i| [dot(row, vector), i] }
      matches = scored.max_by(top_k, &:first).select { |score, _| score >= MIN_SCORE }

      { query: query, results: matches.map { |score, i| result(data[:meta][i], score) } }
    end

    private

    def result(chunk, score)
      {
        source: source_label(chunk),
        kind: chunk["kind"],
        date: chunk["date"],
        url: chunk["url"],
        relevance: score.round(3),
        # Podcast chunks open with a [show, date: title] line; it is in source.
        excerpt: chunk["text"].to_s.sub(/\A\[[^\]\n]*\]\s*/, "")
      }.compact
    end

    def source_label(chunk)
      return chunk["source"] unless chunk["show"] || chunk["title"]

      # Some feeds give a slug ("61-qa-debt-recycling") rather than a number.
      episode = chunk["episode"].to_s.match?(/\A\d+[a-z]?\z/i) ? " episode #{chunk['episode']}" : ""
      [chunk["show"] && "#{chunk['show']}#{episode}", chunk["title"]].compact.join(": ")
    end

    # Loaded on first search and again whenever rag/embed.rb rewrites the files.
    def index
      @lock.synchronize do
        stamp = FILES.map { |f| @dir.join(f).mtime }.max
        @index = load_index.merge(stamp: stamp) if @index.nil? || @index[:stamp] != stamp
        @index
      end
    end

    def load_index
      dims = JSON.parse(@dir.join("info.json").read).fetch("dims")
      rows = @dir.join("embeddings.bin").binread.unpack("e*").each_slice(dims).to_a
      meta = @dir.join("meta.jsonl").each_line.filter_map { |l| JSON.parse(l) unless l.strip.empty? }
      raise "Reference index is inconsistent: #{rows.size} vectors, #{meta.size} chunks" if rows.size != meta.size

      { rows: rows, meta: meta }
    end

    def normalise(vector)
      norm = Math.sqrt(vector.sum { |x| x * x })
      norm.zero? ? vector : vector.map { |x| x / norm }
    end

    def dot(a, b)
      sum = 0.0
      i = 0
      while i < a.size
        sum += a[i] * b[i]
        i += 1
      end
      sum
    end
  end
end
