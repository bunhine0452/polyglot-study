import csv
import io
import json


def csv_to_json(text):
    # 1) csv.reader 와 io.StringIO 로 text 를 행 리스트로 읽는다.
    # 2) 첫 행은 헤더다. 데이터 행이 없으면 "[]" 를 돌려준다.
    # 3) 데이터 행마다 헤더를 키로 하는 딕셔너리를 만든다.
    # 4) 그 딕셔너리들의 리스트를 json.dumps(..., ensure_ascii=False) 로 돌려준다.
    return ""
