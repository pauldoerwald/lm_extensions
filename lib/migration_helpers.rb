module MigrationHelpers
  def foreign_key(from_table, from_column, to_table, to_column="id")
    execute %{alter table #{from_table}
              add constraint fk_#{from_table}_#{from_column}
              foreign key (#{from_column})
              references #{to_table}(#{to_column})}
  end
            
  def foreign_key_with_cascade(from_table, from_column, to_table, to_column="id")
    execute %{alter table #{from_table}
              add constraint fk_#{from_table}_#{from_column}
              foreign key (#{from_column})
              references #{to_table}(#{to_column})
              on delete cascade}
  end
  
  def drop_constraint(from_table, constraint)
    execute %{alter table #{from_table}
              drop constraint #{constraint}}
  end
  
  def drop_foreign_key(from_table, from_column)
    drop_constraint(from_table, "fk_#{from_table}_#{from_column}")
  end
end

class ActiveRecord::Migration
  extend MigrationHelpers
end
