import csv
import io
import json


def csv_to_json(text):
    rows = list(csv.reader(io.StringIO(text)))
    if len(rows) < 2:
        return "[]"
    header = rows[0]
    records = []
    for row in rows[1:]:
        record = {}
        for i in range(len(header)):
            record[header[i]] = row[i]
        records.append(record)
    return json.dumps(records, ensure_ascii=False)
