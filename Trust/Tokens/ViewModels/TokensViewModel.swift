// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import RealmSwift

enum TokenItem {
    case token(TokenObject)
}

struct TokensViewModel {
    /// config of a `TokensViewModel` to give access configuration info.
    let config: Config
    /// realmDataStore of a `TokensViewModel` to give access to Realm instance.
    let realmDataStore: TokensDataStore
    /// tokensNetwork of a `TokensViewModel` to give access to do network requests.
    var tokensNetwork: TokensNetworkProtocol
    /// tokens of a `TokensViewModel` to represent current tokens in the data store.
    let tokens: Results<TokenObject>
    /// tokensObserver of a `TokensViewModel` to track changes in the data store.
    var tokensObserver: NotificationToken?
    /// tableView of a `TokensViewModel` reference to the UITableView.
    weak var tableView: UITableView!
    /// headerBalance of a `TokensViewModel` color of the balance background view.
    var headerBalance: String? {
        return amount
    }
    /// headerBalance of a `TokensViewModel` total amount in fiat value.
    var headerBalanceTextColor: UIColor {
        return Colors.black
    }
    /// headerBackgroundColor of a `TokensViewModel` total amount in fiat value.
    var headerBackgroundColor: UIColor {
        return .white
    }
    /// headerBalanceFont of a `TokensViewModel` font for balance lable.
    var headerBalanceFont: UIFont {
        return UIFont.systemFont(ofSize: 26, weight: .medium)
    }
    /// title of a `TokensViewModel` title of the view controller.
    var title: String {
        return NSLocalizedString("tokens.navigation.title", value: "Tokens", comment: "")
    }
    /// backgroundColor of a `TokensViewModel` color of the background.
    var backgroundColor: UIColor {
        return .white
    }
    /// hasContent of a `TokensViewModel` where to show empty state for table view.
    var hasContent: Bool {
        return !tokens.isEmpty
    }
    /// footerTitle of a `TokensViewModel` localized footer lable title.
    var footerTitle: String {
        return NSLocalizedString("tokens.footer.label.title", value: "Tokens will appear automagically. + to add manually.", comment: "")
    }
    /// footerTextColor of a `TokensViewModel` footer view text color.
    var footerTextColor: UIColor {
        return Colors.black
    }
    /// footerTextFont of a `TokensViewModel` footer lable text font.
    var footerTextFont: UIFont {
        return UIFont.systemFont(ofSize: 13, weight: .light)
    }
    /// Custom init
    ///
    /// - Parameters:
    ///   - config: current config of the app.
    ///   - realmDataStore: data store.
    init(
        config: Config = Config(),
        realmDataStore: TokensDataStore,
        tokensNetwork: TokensNetworkProtocol
    ) {
        self.config = config
        self.realmDataStore = realmDataStore
        self.tokensNetwork = tokensNetwork
        self.tokens = realmDataStore.tokens
    }
    /// Start observation of the tokens.
    mutating func setTokenObservation(with block: @escaping (RealmCollectionChange<Results<TokenObject>>) -> Void) {
        tokensObserver = tokens.observe(block)
    }
    /// amount of a `TokensViewModel` total amount of the all tokens in current fiat value.
    private var amount: String? {
        var totalAmount: Double = 0
        tokens.forEach { token in
            totalAmount += amount(for: token)
        }
        guard totalAmount != 0 else { return "--" }
        return CurrencyFormatter.formatter.string(from: NSNumber(value: totalAmount))
    }
    /// Amount in fiar value per token.
    ///
    /// - Parameters:
    ///   - token: current token to fetch price for.
    /// - Returns: `Double` price of the token.
    private func amount(for token: TokenObject) -> Double {
        guard let tickersSymbol = realmDataStore.tickers.first(where: { $0.contract == token.contract }) else { return 0 }
        let tokenValue = CurrencyFormatter.plainFormatter.string(from: token.valueBigInt, decimals: token.decimals).doubleValue
        let price = Double(tickersSymbol.price) ?? 0
        return tokenValue * price
    }
    /// Numbers of items in table view section.
    ///
    /// - Parameters:
    ///   - section: for wahat section to return items count.
    /// - Returns: `Int` number of items per section.
    func numberOfItems(for section: Int) -> Int {
        return tokens.count
    }
    /// TokenItem for index path.
    ///
    /// - Parameters:
    ///   - path: of the item.
    /// - Returns: `TokenItem` in the current data source.
    func item(for path: IndexPath) -> TokenItem {
        return .token(tokens[path.row])
    }
    /// Can cell be editable.
    ///
    /// - Parameters:
    ///   - path: of the item.
    /// - Returns: `Bool` if cell is editable.
    func canEdit(for path: IndexPath) -> Bool {
        let token = item(for: path)
        switch token {
        case .token(let token):
            return token.isCustom
        }
    }
    /// View model for cell.
    ///
    /// - Parameters:
    ///   - path: of the item.
    /// - Returns: `TokenViewCellViewModel` model to update cell.
    func cellViewModel(for path: IndexPath) -> TokenViewCellViewModel {
        let token = tokens[path.row]
        return TokenViewCellViewModel(token: token, ticker: realmDataStore.coinTicker(for: token))
    }
    /// Update enabled tokens tickers.
    func updateTickers() {
        tokensNetwork.tickers(for: realmDataStore.enabledObject) { result in
            guard let tickers = result else { return }
            self.realmDataStore.tickers = tickers
        }
    }
    /// Update current eth balance.
    func updateEthBalance() {
        tokensNetwork.ethBalance { result in
            guard let balance = result else { return }
            self.realmDataStore.update(token: TokensDataStore.etherToken(for: self.config), action: TokenAction.updateValue(balance.value))
        }
    }
    /// Update tokens balance.
    func updateTokensBalances() {
        realmDataStore.enabledObject.forEach { token in
            tokensNetwork.tokenBalance(for: token) { result in
                guard let balance = result.1 else { return }
                self.realmDataStore.update(token: result.0, action: TokenAction.updateValue(balance.value))
            }
        }
    }
}
