module Reports
  module TotalInventoryValue

    def self.new(params, _session)
      if params[:category_id].present?
        Reports::TotalInventoryValue::SingleCategory.new(params)
      else
        Reports::TotalInventoryValue::AllCategories.new(params)
      end
    end

    module Common
      def date_range
        valid_date_range = @params[:date_range].is_a?(Range) &&
          @params[:date_range].first.is_a?(Time) &&
          @params[:date_range].last.is_a?(Time)

        if valid_date_range == true
          return @params[:date_range]
        end
      end

      def fetch_total_value(obj)
        if obj.is_a?(Item)
          item_id = obj.id.to_s
          return (items_data[item_id]["quantity"] || 0).to_i * items_data[item_id]["value"].to_f
        elsif obj.is_a?(Category)
          # Find all items that are associated with the category.
          category_id = obj.id.to_s

          category_total_value = 0
          relevant_items = items_data.select { |id, data| data["category_id"] == category_id }

          relevant_items.each do |id, data|
            item_total = data.fetch("quantity", 0).to_i * data["value"].to_f
            category_total_value = category_total_value + item_total
          end

          return category_total_value
        end
      end

      def items_data
        # Fetches historically what the data should be at a given time.
        @items_data ||= {}
        return @items_data unless @items_data.empty?

        results = ActiveRecord::Base.connection.execute(items_data_sql)
        results.each do |r|
          @items_data[r['id']] = r
        end

        return @items_data
      end

      def date_range_conditional
        return nil unless date_range.present?

        start_date_range = date_range.first.to_s(:db)
        end_date_range = date_range.last.to_s(:db)

        return "AND versions.created_at BETWEEN '#{start_date_range}' AND '#{end_date_range}'"
      end

      def items_data_sql
        """
          SELECT id, description, category_id, value,
            (
              SELECT versions.object->'current_quantity' FROM versions 
              WHERE versions.item_id = items.id 
              AND versions.item_type = 'Item'
              #{date_range_conditional}
              ORDER BY versions.created_at DESC 
              LIMIT 1
            ) as quantity
          FROM items
        """
      end
    end

    class SingleCategory
      include TotalInventoryValue::Common
      attr_reader :category

      def initialize(params = {})
        @category = Category.find(params[:category_id])
        @params = params
      end

      def each
        category.items.order(:description).each do |item|
          yield item.description, fetch_total_value(item)
        end
      end

      def total_value
        category.value
      end
    end

    class AllCategories
      include TotalInventoryValue::Common
      attr_reader :categories

      def initialize(params = {})
        @categories = Category.all
        @params = params
      end

      def each
        categories.each do |category|
          yield category.description, fetch_total_value(category)
        end
      end

      def total_value
        @categories.inject(0) do |sum, c|
          sum += fetch_total_value(c)
        end
      end
    end

  end
end
