//
//  main.swift
//  play
//
//  Created by Родион Холодов on 10.09.2026.
//

// MARK: - Задача 1

struct Order {
    let id: Int
    let customer: String
    let amount: Double // сумма заказа
    let isPaid: Bool
    let promoCode: String? // может отсутствовать
}

let orders: [Order] = [
    Order(id: 1, customer: "Анна", amount: 1200, isPaid: true, promoCode: "SALE10"),
    Order(id: 2, customer: "Иван", amount: 800, isPaid: false, promoCode: nil),
    Order(id: 3, customer: "Анна", amount: 5400, isPaid: true, promoCode: nil),
    Order(id: 4, customer: "Олег", amount: 300, isPaid: true, promoCode: "NEW"),
    Order(id: 5, customer: "Иван", amount: 2100, isPaid: false, promoCode: "SALE10")
]

// Получить массив сумм всех оплаченных заказов.
print()
print("Пункт1")
let paidOrdersArray = orders.filter{ $0.isPaid }.map{ $0.amount }
print(paidOrdersArray)

// Найти общую сумму всех неоплаченных заказов (reduce).
print()
print("Пункт2")
let totalSumNoPaidOrders = orders.reduce(0.0) { partialResult, order in
    if order.isPaid == false {
        return partialResult + order.amount
    }
    return partialResult
}
print(totalSumNoPaidOrders)

// Получить список уникальных имён клиентов, отсортированный по алфавиту.
print()
print("Пункт3")
let ordersSet = Set(orders.map { $0.customer })
let uniqueNames = ordersSet.sorted()
print(uniqueNames)

// Получить массив промокодов, исключив nil (compactMap).
print()
print("Пункт4")
let promoArr = orders.compactMap { $0.promoCode }
print(promoArr)

// Сгруппировать заказы по имени клиента в словарь [String: [Order]] (через Dictionary(grouping:by:)).
print()
print("Пункт5")
let groupedOrdersByName = Dictionary(grouping: orders, by: { $0.customer })
print(groupedOrdersByName)

// Найти клиента с максимальной суммарной оплаченной суммой.
print()
print("Пункт6")
let customerWithMaxPaidAmount = Dictionary(grouping: orders.filter { $0.isPaid }, by: { $0.customer })
    .mapValues { $0.reduce(0.0) { $0 + $1.amount } }
    .max { $0.value < $1.value }
if let customer = customerWithMaxPaidAmount {
    print("\(customer.key) с суммой \(customer.value)")
} else {
    print("не нашлось такого клиента")
}

// MARK: - Задача 2

//    Point — структура с x, y типа Double:
//
//    mutating func move(byX:byY:);
//
//    вычисляемое свойство distanceToOrigin: Double;
//
//    соответствие Equatable, Hashable.

import Foundation

struct Point: Equatable, Hashable {
    var x: Double
    var y: Double
    
    var distanceToOrigin: Double {
        hypot(x, y)
    }
    
    mutating func move(byX dx: Double, byY dy: Double) {
        x += dx
        y += dy
    }
}
 
//    Rectangle — структура с origin: Point, width, height:
//
//    вычисляемые свойства area, perimeter, center;
//
//    mutating func scale(by factor: Double);
//
//    func contains(_ point: Point) -> Bool;
//
//    init с валидацией: если width <= 0 или height <= 0 — использовать значения по умолчанию 1.0.

struct Rectangle {
    var origin: Point
    var width: Double
    var height: Double
    
    var area: Double {
        width * height
    }
    
    var perimeter: Double {
        2 * width + 2 * height
    }
    
    var center: Point {
        Point(x: origin.x + width / 2, y: origin.y + height / 2)
    }
    
    mutating func scale(by factor: Double) {
        width *= factor
        height *= factor
    }
    
    func contains(_ point: Point) -> Bool {
        point.x >= origin.x && point.x < origin.x + width &&
        point.y >= origin.y && point.y < origin.y + height
    }
    
    init(origin: Point, width: Double, height: Double) {
        self.origin = origin
        self.width = width > 0 ? width : 1.0
        self.height = height > 0 ? height : 1.0
    }
}

// MARK: - Задача 3
// Реализовать очередь с приоритетом кастомную
print()
print("Задача 3")
class PriorityQueue<T: Comparable> {
    struct Elem {
        let priority: Int
        let value: T
    }
    
    var elems = [Elem]()
    
    func enqueue(priority: Int, value: T) {
        elems.append(Elem(priority: priority, value: value))
    }
    
    func dequeue() -> T? {
        guard isEmpty == false else { return nil }
        let mixPriorityElem = elems.min { $0.priority < $1.priority }
        guard let index = elems.firstIndex(where: { $0.priority == mixPriorityElem?.priority }) else { return nil }
        elems.remove(at: index)
        
        return mixPriorityElem?.value
    }
    
    var isEmpty: Bool {
        elems.isEmpty
    }
    
    var count: Int {
        elems.count
    }
    
    func peek() -> T? {
        elems.max { $0.priority < $1.priority }?.value
    }
}

// для примера [(2, Петя), (1, Толик), (3, Сеня)]
var queue = PriorityQueue<String>()

queue.enqueue(priority: 2, value: "Петя")
queue.enqueue(priority: 1, value: "Толик")
queue.enqueue(priority: 3, value: "Сеня")

let first = queue.dequeue() ?? "No first value"
let second = queue.dequeue() ?? "No second value"
let third = queue.dequeue() ?? "No third value"
let noValue = queue.dequeue() ?? "nil"

// Ждем "Толик, Петя, Сеня, nil"
print("\(first), \(second), \(third), \(noValue)")
