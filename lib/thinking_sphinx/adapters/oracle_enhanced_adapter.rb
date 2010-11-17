module ThinkingSphinx
  class OracleEnhancedAdapter < AbstractAdapter
    def setup
      create_crc32_function
    end

    def sphinx_identifier
      "odbc"
    end

    def concatenate(clause, separator = ' ')
      "CONCAT_WS('#{separator}', #{clause})"
    end

    def group_concatenate(clause, separator = ' ')
      "TRIM(RTRIM(REPLACE(REPLACE(XMLAgg(XMLElement(\"x\", #{clause} )), '<x>', ' '), '</x>', '#{separator}'), '#{separator}'))"
    end

    def cast_to_string(clause)
      "CAST(#{clause} AS VARCHAR2(500))"
    end

    def cast_to_datetime(clause)
      "(#{clause} - to_date('01-JAN-1970','DD-MON-YYYY')) * (86400)"
    end

    def cast_to_unsigned(clause)
      "ABS(#{clause})"
    end

    def convert_nulls(clause, default = '')
      default = "'#{default}'" if default.is_a?(String)
      "NULLIF(#{clause}, #{default})"
    end

    def boolean(value)
      value ? 1 : 0
    end

    def crc(clause, blank_to_null = false)
      clause = "NULLIF(#{clause},'')" if blank_to_null
      "ORA_HASH(#{clause})"
    end

    def time_difference(diff)
      # "DATE_SUB(NOW(), INTERVAL #{diff} SECOND)"
      "sysdate - INTERVAL '#{diff}' SECOND"
    end

    def utc_query_pre
      "ALTER SESSION SET TIME_ZONE='+00:00'"
    end

    def utf8_query_pre
      nil
    end

    private

    # Requires Oracle 10g+
    def create_crc32_function
      connection.execute <<-SQL
CREATE OR REPLACE FUNCTION crc32(
word IN VARCHAR2
) RETURN NUMBER IS
code NUMBER(4,0);
i NUMBER(10,0);
j NUMBER(1,0);
tmp NUMBER(10,0);
tmp_a NUMBER(10,0);
tmp_b NUMBER(10,0);
BEGIN
tmp := 4294967295;
i := 0;
WHILE i < length(word) LOOP
code := ascii(SUBSTR(word, i + 1, 1));
tmp := tmp - 2 * to_number(bitand(tmp, code)) + code;
j := 0;
WHILE j < 8 LOOP
tmp_a := floor(tmp / 2);
tmp_b := 3988292384 * to_number(bitand(tmp, 1));
tmp := tmp_a - 2 * to_number(bitand(tmp_a, tmp_b)) + tmp_b;
j := j + 1;
END LOOP;
i := i + 1;
END LOOP;
RETURN tmp - 2 * to_number(bitand(tmp, 4294967295)) + 4294967295;
END crc32;
SQL
    end
  end
end
