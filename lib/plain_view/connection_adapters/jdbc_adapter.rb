module PlainView
  module ConnectionAdapters
    module SchemaStatements
      def self.included(base)
        base.alias_method_chain :drop_table, :cascade
      end
    end
    
    module JdbcAdapter
      def self.included(base)	
				# If we do not remove this method it ends up as the overriding method
				JdbcSpec::MySQL.module_eval do
					if private_method_defined?(:supports_views?)
						remove_method(:supports_views?) 
					end
				end
      end

      # Returns true as this adapter supports views.
      def supports_views?
        true
      end

      def base_tables(name = nil) #:nodoc:
				# Result is an array that looks like this: 
				# [{"Tables_in_account_dev"=>"account_friends", "Table_type"=>"BASE TABLE"}, ...]
				tables = execute("SHOW FULL TABLES WHERE TABLE_TYPE='BASE TABLE'").inject([]) do |table, row| 
					table << row.values.reject{|v| v == "BASE TABLE"}
					table					
				end
				tables.flatten
      end

      alias nonview_tables base_tables

      def views(name = nil) #:nodoc:
        views = execute("SHOW FULL TABLES WHERE TABLE_TYPE='VIEW'").inject([]) do |view, row| 
					view << row.values.reject{|v| v == "VIEW"}
					view					
				end
				views.flatten
      end

      def structure_dump
        structure = ""
        base_tables.each do |table|
          structure += select_one("SHOW CREATE TABLE #{quote_table_name(table)}")["Create Table"] + ";\n\n"
        end

        views.each do |view|
          structure += select_one("SHOW CREATE VIEW #{quote_table_name(view)}")["Create View"] + ";\n\n"
        end

        return structure
      end

      # Get the view select statement for the specified table.
      def view_select_statement(view, name=nil)
				# Result looks like this:
				# [{"View"=>"mutual_account_friends", "Create View"=>"CREATE ALGORITHM=MERGE DEFINER=`server_dev`@`localhost` SQL SECURITY INVOKER VIEW `mutual_account_friends` AS select ...", "character_set_client"=>"utf8", "collation_connection"=>"utf8_general_ci"}]
        begin
					statement = execute("SHOW CREATE VIEW #{view}", name).first["Create View"]
					if statement.include?("SECURITY INVOKER")  ## Remove DEFINER if the INVOKER security model
						statement.gsub!(/DEFINER=\S+\s+/, '')
					end
          return statement #convert_statement(row[1]) if row[0] == view
        rescue ActiveRecord::StatementInvalid => e
          raise "No view called #{view} found"
        end
      end

      private
      def convert_statement(s)
        s.gsub!(/.* AS (select .*)/, '\1')
      end
    end
		
	end
end