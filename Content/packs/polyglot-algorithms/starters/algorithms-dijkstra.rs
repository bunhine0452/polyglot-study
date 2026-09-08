pub fn dijkstra(adj: &Vec<Vec<(usize, u32)>>, start: usize) -> Vec<u32> {
    // dist 를 시작 정점만 0, 나머지는 u32::MAX 로 초기화해라.
    // 매 라운드: 미확정 정점 중 dist 가 가장 작은 정점을 골라 확정하고, 그 이웃들의
    // dist 를 갱신해라 (dist[u] + w 가 더 작을 때만).
    unimplemented!("여기를 구현해라")
}
