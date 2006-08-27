# Multi line accessor fails in rtags < 0.93
# 
      class Hit
        def initialize
          @hsps = []
        end
        attr_reader :hsps
        attr_accessor :query_id, :query_def, :query_len,
          :num, :hit_id, :len, :definition, :accession

        def each
          @hsps.each do |x|
            yield x 
          end
        end
      end
