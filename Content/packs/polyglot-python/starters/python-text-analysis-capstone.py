def analyze_words(text, top_n=3):
    # 1) text 를 소문자로 바꾸고 split() 으로 단어 리스트를 만든다.
    # 2) 각 단어의 개수를 dict.get(word, 0) + 1 패턴으로 센다.
    # 3) sorted() 의 key 에 람다를 넣어 개수 내림차순,
    #    개수가 같으면 단어 오름차순으로 정렬한다.
    # 4) 상위 top_n 개만 슬라이싱해서 반환한다.
    pass
