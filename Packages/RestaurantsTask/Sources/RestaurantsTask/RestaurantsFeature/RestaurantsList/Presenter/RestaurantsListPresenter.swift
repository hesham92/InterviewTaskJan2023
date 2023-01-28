import Foundation

enum RestaurantsListState: Equatable {
    case idle
    case loading
    case loaded([Restaurant])
    case error(String)
}

protocol RestaurantsListPresenter {
    var state: RestaurantsListState { get }
    func configure(with viewDelegate: RestaurantsListView)
    func didSelectRestaurantAtIndex(index: Int)
    func didSelectSegmentAtIndex(index: Int)
    func viewDidLoad() async
}

protocol RestaurantsListView: AnyObject {
    func stateDidChange()
    func navigateToRestaurantDetails(restaurant: Restaurant)
}

final class DefaultRestaurantsListPresenter: RestaurantsListPresenter {
    // MARK: - Public
    init(service: HttpServiceProtocol = HttpService()){
        self.service = service
    }
    
    private(set) var state: RestaurantsListState = .idle {
        didSet {
            view?.stateDidChange()
        }
    }
    
    func didSelectRestaurantAtIndex(index: Int) {
        view?.navigateToRestaurantDetails(restaurant: restaurants[index])
    }
    
    func didSelectSegmentAtIndex(index: Int) {
        var sortedRestaurants: [Restaurant] = []
        
        switch SortingCriteria(rawValue: index) {
        case .default, .none:
            sortedRestaurants = restaurants
        case .distance:
            sortedRestaurants = restaurants.sorted { String($0.distance) < String($1.distance) }
        case .rating:
            sortedRestaurants = restaurants.sorted { String($0.rating) > String($1.rating) }
        }
        
        state = .loaded(sortedRestaurants)
    }
    
    func configure(with viewDelegate: RestaurantsListView) {
        view = viewDelegate
    }
    
    func viewDidLoad() async {
        await fetchRestaurants()
    }
    
    // MARK: - Private
    @MainActor
    private func fetchRestaurants() async {
        self.state = .loading
        
        do {
            restaurants = try await service.request(endpoint: RestaurantsEndpoint.getRestaurants, modelType: [Restaurant].self)
            state = .loaded(restaurants)
        } catch {
            restaurants.removeAll()
            state = .error(error.localizedDescription)
        }
    }
    
    enum SortingCriteria: Int, CaseIterable {
        case `default` = 0
        case distance = 1
        case rating = 2
    }
    
    private let service: HttpServiceProtocol
    private weak var view: RestaurantsListView?
    private var restaurants: [Restaurant] = []
}
