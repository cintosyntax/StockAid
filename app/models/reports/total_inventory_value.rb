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
      def start_date
        Time.parse(@params[:report_start_date]) if @params[:report_start_date].present?
      rescue
        nil
      end

      def end_date
        Time.parse(@params[:report_end_date]) if @params[:report_end_date].present?
      rescue
        nil
      end

      def valid?
        @errors = []

        if (@params[:report_start_date].present? || @params[:report_end_date].present?) && date_range.blank?
          @errors << "Invalid dates provided in range."
        end

        if start_date.present? && end_date.present? && start_date > end_date
          @errors << "Invalid date range provided."
        end

        return @errors.blank?
      end

      def errors
        @errors
      end

      def date_range
        if start_date.present? && end_date.present?
          return start_date..end_date
        end
      end

      def fetch_total_value(obj)
        if obj.is_a?(Item)
          item_id = obj.id.to_s

          item_quantity = fetch_item_quantity(items_data[item_id])

          item_quantity = (items_data[item_id]["quantity"] || items_data[item_id]["current_quantity"] || 0).to_i
          return item_quantity * items_data[item_id]["value"].to_f
        elsif obj.is_a?(Category)
          # Find all items that are associated with the category.
          category_id = obj.id.to_s

          category_total_value = 0
          relevant_items = items_data.select { |id, data| data["category_id"] == category_id }

          relevant_items.each do |id, data|
            item_quantity = fetch_item_quantity(data)

            item_total = item_quantity * data["value"].to_f
            category_total_value = category_total_value + item_total
          end

          return category_total_value
        end
      end

      def fetch_item_quantity(item_data)
        if end_date.present? && end_date >= Time.parse(item_data["updated_at"])
          # Handle case in which the end_date exceeds the latest version. Instead
          # use the current quantity instead of relying on the previous version
          # data.
          return item_data["current_quantity"].to_i
        end

        return (item_data["quantity"] || item_data["current_quantity"] || 0).to_i
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
          SELECT id, description, category_id, value, current_quantity, updated_at,
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
