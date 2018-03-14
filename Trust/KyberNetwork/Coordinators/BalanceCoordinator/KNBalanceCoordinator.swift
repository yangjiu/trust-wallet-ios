// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore

class KNBalanceCoordinator {

  enum KNBalanceNotificationKeys: String {
    case ethBalanceDidUpdate
    case otherTokensBalanceDidUpdate
  }

  fileprivate let session: KNSession

  fileprivate var fetchETHBalanceTimer: Timer?
  fileprivate var isFetchingETHBalance: Bool = false
  var ethBalance: Balance = Balance(value: BigInt(0))

  fileprivate var fetchOtherTokensBalanceTimer: Timer?
  fileprivate var isFetchingOtherTokensBalance: Bool = false
  var otherTokensBalance: [String: Balance] = [:]

  init(session: KNSession) {
    self.session = session
  }

  func resume() {
    fetchETHBalanceTimer?.invalidate()
    isFetchingETHBalance = false
    fetchETHBalance(nil)

    fetchETHBalanceTimer = Timer.scheduledTimer(
      timeInterval: KNLoadingInterval.defaultLoadingInterval,
      target: self,
      selector: #selector(self.fetchETHBalance(_:)),
      userInfo: nil,
      repeats: true
    )

    fetchOtherTokensBalanceTimer?.invalidate()
    isFetchingOtherTokensBalance = false
    fetchOtherTokensBalance(nil)

    fetchETHBalanceTimer = Timer.scheduledTimer(
      timeInterval: KNLoadingInterval.defaultLoadingInterval,
      target: self,
      selector: #selector(self.fetchOtherTokensBalance(_:)),
      userInfo: nil,
      repeats: true
    )
  }

  func pause() {
    fetchETHBalanceTimer?.invalidate()
    fetchETHBalanceTimer = nil
    isFetchingETHBalance = true

    fetchOtherTokensBalanceTimer?.invalidate()
    fetchOtherTokensBalanceTimer = nil
    isFetchingOtherTokensBalance = true
  }

  func exit() {
    pause()
  }

  @objc func fetchETHBalance(_ sender: Timer?) {
    if isFetchingETHBalance { return }
    isFetchingETHBalance = true
    self.session.externalProvider.getETHBalance(address: self.session.wallet.address) { [weak self] result in
      guard let `self` = self else { return }
      self.isFetchingETHBalance = false
      switch result {
      case .success(let balance):
        self.ethBalance = balance
        KNNotificationUtil.postNotification(for: KNBalanceNotificationKeys.ethBalanceDidUpdate.rawValue)
      case .failure(let error):
        NSLog("Load ETH Balance failed with error: \(error.description)")
      }
    }
  }

  @objc func fetchOtherTokensBalance(_ sender: Timer?) {
    if isFetchingOtherTokensBalance { return }
    isFetchingOtherTokensBalance = true
    let tokens = KNJSONLoaderUtil.loadListSupportedTokensFromJSONFile()
    let group = DispatchGroup()
    for token in tokens {
      if let contractAddress = Address(string: token.address), token.symbol != "ETH" {
        group.enter()
        self.session.externalProvider.getTokenBalance(
          for: self.session.wallet.address,
          contract: contractAddress,
          completion: { [weak self] result in
            guard let `self` = self else { return }
            switch result {
            case .success(let bigInt):
              let balance = Balance(value: bigInt)
              self.otherTokensBalance[token.address] = balance
              NSLog("Done loading \(token.symbol) balance: \(balance.amountFull)")
            case .failure(let error):
              NSLog("Load \(token.symbol) balance failed with error: \(error.description)")
            }
            group.leave()
        })
      }
    }
    // notify when all load balances are done
    group.notify(queue: .main) {
      self.isFetchingOtherTokensBalance = false
      KNNotificationUtil.postNotification(for: KNBalanceNotificationKeys.otherTokensBalanceDidUpdate.rawValue)
    }
  }
}