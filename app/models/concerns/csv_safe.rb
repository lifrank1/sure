# Guards against CSV/formula injection (OWASP): when a spreadsheet app opens an
# exported CSV, a cell whose text begins with =, +, -, @, TAB or CR is
# interpreted as a formula. User-editable free text (category/account/merchant
# names, notes, tags) must be neutralized before being written to an export
# that lands in Excel/Sheets/LibreOffice. Prefix such values with a single
# quote so they render as literal text.
module CsvSafe
  module_function

  DANGEROUS_PREFIX = /\A[=+\-@\t\r]/

  def csv_safe(value)
    str = value.to_s
    str.match?(DANGEROUS_PREFIX) ? "'#{str}" : str
  end
end
