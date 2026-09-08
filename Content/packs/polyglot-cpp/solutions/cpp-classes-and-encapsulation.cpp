class Stock {
 public:
    Stock(int initial) {
        quantity = (initial < 0) ? 0 : initial;
    }

    void add(int amount) {
        if (amount > 0) {
            quantity += amount;
        }
    }

    bool remove(int amount) {
        if (amount <= 0 || amount > quantity) {
            return false;
        }
        quantity -= amount;
        return true;
    }

    int getQuantity() const {
        return quantity;
    }

 private:
    int quantity;
};
