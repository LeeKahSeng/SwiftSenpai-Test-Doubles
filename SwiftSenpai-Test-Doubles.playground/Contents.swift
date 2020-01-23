import XCTest

// MARK:- TelevisionWarehouse

struct Television {
    let brand: String
    let price: Double
}

class TelevisionWarehouse {

    private let emailServiceHelper: EmailServiceHelper
    private let databaseReader: DatabaseReader

    private let minStockCount = 3
    private var stocks: [Television]

    // Failable initializer
    // Inject dependencies: DatabaseReader, EmailServiceHelper
    // Initializer will fail when not able to read stocks information from database
    init?(_ databaseReader: DatabaseReader, emailServiceHelper: EmailServiceHelper) {

        self.emailServiceHelper = emailServiceHelper
        self.databaseReader = databaseReader

        let result = databaseReader.getAllStock()

        switch result {
        case .success(let stocks):
            self.stocks = stocks
        case .failure(let error):
            print(error.localizedDescription)
            return nil
        }
    }
    
    var stockCount: Int {
        return stocks.count
    }

    // Add televisions to warehouse
    func add(_ newStocks: [Television]) {
        stocks.append(contentsOf: newStocks)
    }
    
    // Remove televisions from warehouse
    func remove(_ count: Int) {
        
        if count <= stockCount {
            stocks.removeLast(count)
        } else {
            stocks.removeAll()
        }

        // When stock less than minimum threshold, send email to manager
        if stocks.count < minStockCount {
            emailServiceHelper.sendEmail(to: "manager@email.com")
        }
    }
}

// MARK:- Protocols
protocol DatabaseReader {
    func getAllStock() -> Result<[Television], Error>
}

protocol EmailServiceHelper {
    func sendEmail(to address: String)
}

// MARK:- Dummy
// Dummy DatabaseReader
class DummyDatabaseReader: DatabaseReader {
    func getAllStock() -> Result<[Television], Error> {
        return .success([])
    }
}

// Dummy EmailServiceHelper
class DummyEmailServiceHelper: EmailServiceHelper {
    func sendEmail(to address: String) {}
}

// MARK:- Fake
class FakeDatabaseReader: DatabaseReader {

    func getAllStock() -> Result<[Television], Error> {

        // Read JSON file
        let filePath = Bundle.main.path(forResource: "stock_sample", ofType: "json")
        let data = FileManager.default.contents(atPath: filePath!)
        
        // Parse JSON to object
        let decoder = JSONDecoder()
        let result = try! decoder.decode([Television].self, from: data!)

        return .success(result)
    }
}

// Conform Television to Decodable protocol for JSON parsing
extension Television: Decodable {
    
}

// MARK:- Stub
class StubDatabaseReader: DatabaseReader {
    
    enum StubDatabaseReaderError: Error {
        case someError
    }

    func getAllStock() -> Result<[Television], Error> {
        return .failure(StubDatabaseReaderError.someError)
    }
}

// MARK:- Mock
class MockEmailServiceHelper: EmailServiceHelper {
    
    var sendEmailCalled = false
    var emailCounter = 0
    var emailAddress = ""

    func sendEmail(to address: String) {
        sendEmailCalled = true
        emailCounter += 1
        emailAddress = address
    }
}

// MARK:- Unit Test Cases
func testWarehouseInitSuccess() {

    // Create dummies
    let dummyReader = DummyDatabaseReader()
    let dummyEmailService = DummyEmailServiceHelper()
    
    // Initialize TelevisionWarehouse
    let warehouse = TelevisionWarehouse(dummyReader, emailServiceHelper: dummyEmailService)
    
    // Verify warehouse init successful
    XCTAssertNotNil(warehouse)
}

func testWarehouseAddRemoveStock() {
    
    let fakeReader = FakeDatabaseReader()
    let dummyEmailService = DummyEmailServiceHelper()
    
    let warehouse = TelevisionWarehouse(fakeReader, emailServiceHelper: dummyEmailService)!
    
    // Add 2 televisions to warehouse
    warehouse.add([
        Television(brand: "Toshiba", price: 199),
        Television(brand: "Toshiba", price: 199)
    ])
    
    // Remove 4 televisions from warehouse
    warehouse.remove(4)
    
    // Verify stock count is correct
    XCTAssertEqual(warehouse.stockCount, 1)
    
    // Remove amount more than stock count
    warehouse.remove(100)
    
    // Verify that stock count is 0
    XCTAssertEqual(warehouse.stockCount, 0)
}

func testWarehouseInitFail() {
    
    let stubReader = StubDatabaseReader()
    let dummyEmailService = DummyEmailServiceHelper()
    
    let warehouse = TelevisionWarehouse(stubReader, emailServiceHelper: dummyEmailService)

    // Verify warehouse object is nil
    XCTAssertNil(warehouse)
}

func testWarehouseSendEmail() {
    
    // FakeDatabaseReader will load 3 televisions
    let fakeReader = FakeDatabaseReader()
    let mockEmailService = MockEmailServiceHelper()
    
    let warehouse = TelevisionWarehouse(fakeReader, emailServiceHelper: mockEmailService)!
    
    // Remove warehouse's stocks to trigger notification email
    warehouse.remove(3)

    // Verify sendEmail(to:) called
    XCTAssertTrue(mockEmailService.sendEmailCalled)

    // Verify only 1 email being sent
    XCTAssertEqual(mockEmailService.emailCounter, 1)

    // Verify the email's recipient
    XCTAssertEqual(mockEmailService.emailAddress, "manager@email.com")
}

// MARK:- Test Execution
testWarehouseInitSuccess()
testWarehouseAddRemoveStock()
testWarehouseInitFail()
testWarehouseSendEmail()

print("Test Completed")
