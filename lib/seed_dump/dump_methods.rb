class SeedDump
  module DumpMethods
    include Enumeration

    def dump(records, options = {})
      return nil if records.count == 0

      io = open_io(options)

      write_records_to_io(records, io, options)

      ensure
        io.close if io.present?
    end

    private

    def dump_record(record, options)
      attribute_strings = []

      options[:exclude] ||= [:id, :created_at, :updated_at]

      # We select only string attribute names to avoid conflict
      # with the composite_primary_keys gem (it returns composite
      # primary key attribute names as hashes).
      record.attributes.select {|key| key.is_a?(String) }.each do |attribute, value|
        attribute_strings << dump_attribute_new(attribute, value) unless options[:exclude].include?(attribute.to_sym)
      end

      "{#{attribute_strings.join(", ")}}"
    end

    def dump_attribute_new(attribute, value)
      "#{attribute}: #{value_to_s(value)}"
    end

    def value_to_s(value)
      value = case value
              when BigDecimal
                value.to_s
              when Date, Time, DateTime
                value.to_s(:db)
              when Range
                range_to_string(value)
              when RGeo::Cartesian::PointImpl
                value.to_s
              else
                value
              end

      value.inspect
    end

    def range_to_string(object)
      from = object.begin.respond_to?(:infinite?) && object.begin.infinite? ? '' : object.begin
      to   = object.end.respond_to?(:infinite?) && object.end.infinite? ? '' : object.end
      "[#{from},#{to}#{object.exclude_end? ? ')' : ']'}"
    end

    def open_io(options)
      if options[:file].present?
        mode = options[:append] ? 'a+' : 'w+'

        File.open(options[:file], mode)
      else
        StringIO.new('', 'w+')
      end
    end

    def write_records_to_io(records, io, options)
      io.write("#{model_for(records)}.create!([\n  ")

      enumeration_method = if records.is_a?(ActiveRecord::Relation) || records.is_a?(Class)
                             :active_record_enumeration
                           else
                             :enumerable_enumeration
                           end

      send(enumeration_method, records, io, options) do |record_strings, last_batch|
        io.write(record_strings.join(",\n  "))

        io.write(",\n  ") unless last_batch
      end

      io.write("\n])\n")

      if options[:file].present?
        nil
      else
        io.rewind
        io.read
      end
    end

    def model_for(records)
      if records.is_a?(Class)
        records
      elsif records.respond_to?(:model)
        records.model
      else
        records[0].class
      end
    end

  end
end
