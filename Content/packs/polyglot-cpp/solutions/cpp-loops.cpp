int sumSkipMultiplesOfThree(int n) {
    int sum = 0;
    for (int i = 1; i <= n; ++i) {
        if (i % 3 == 0) {
            continue;
        }
        sum += i;
        if (sum > 100) {
            break;
        }
    }
    return sum;
}
