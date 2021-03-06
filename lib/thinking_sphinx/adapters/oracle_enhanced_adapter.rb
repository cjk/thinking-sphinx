module ThinkingSphinx
  class OracleEnhancedAdapter < AbstractAdapter
    def setup
      create_crc32_function
      create_varchar2_ntt_type
      create_tostring_function
    end

    def sphinx_identifier
      "odbc"
    end

    def concatenate(clause, separator = ' ')
      "CONCAT_WS('#{separator}', #{clause})"
    end

    def group_concatenate(clause, separator = ' ')
      "to_string(CAST(collect(to_char(#{clause})) AS varchar2_ntt), '#{separator}')"
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

    def create_varchar2_ntt_type
      connection.execute <<-SQL
CREATE OR REPLACE TYPE varchar2_ntt AS TABLE OF VARCHAR(4000);
SQL
    end

    def create_tostring_function
      connection.execute <<-SQL
CREATE OR REPLACE FUNCTION to_string (
                nt_in        IN varchar2_ntt,
                delimiter_in IN VARCHAR2 DEFAULT ','
                ) RETURN VARCHAR2 IS
   v_idx PLS_INTEGER;
   v_str VARCHAR2(32767);
   v_dlm VARCHAR2(10);
BEGIN
   v_idx := nt_in.FIRST;
   WHILE v_idx IS NOT NULL LOOP
      v_str := v_str || v_dlm || nt_in(v_idx);
      v_dlm := delimiter_in;
      v_idx := nt_in.NEXT(v_idx);
   END LOOP;
   RETURN v_str;
END to_string;
SQL
    end
  end
end
