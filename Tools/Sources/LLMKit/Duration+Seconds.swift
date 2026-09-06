extension Duration {
    /// 초 단위 실수. `URLRequest.timeoutInterval` 처럼 `TimeInterval` 을 받는 자리에 쓴다.
    public var asTimeInterval: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
