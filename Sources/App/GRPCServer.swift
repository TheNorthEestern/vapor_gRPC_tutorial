/// Copyright (c) 2022 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.


import Foundation
import GRPC
import Vapor
import Logging

public extension Application.Servers.Provider {
  static var gRPCServer: Self {
    .init {
      $0.servers.use { app in GRPCServer(application: app)
      }
    }
  }
}

public class GRPCServer: Vapor.Server {

  var port = 1234
  var host = "localhost"
  var application: Application
  var server: GRPC.Server?


  init(application: Application) {
    self.application = application
  }

  public func start(address: BindAddress?) throws {

    switch address {
    case .none:
      break
    case .hostname(let hostname, let port):
      if let hostname = hostname {
        self.host = hostname
      }
      if let port = port {
        self.port = port
      }
    default:
      fatalError()
    }

    //set up logging
    var logger = Logger(label: "grpc", factory: StreamLogHandler.standardOutput)
    logger.logLevel = .debug

    //bind to host and port. do not use SSL
    let group = application.eventLoopGroup
    let server = GRPC.Server.insecure(group: group)
      .withLogger(logger)
      .withServiceProviders([TodoProvider(application)])
      .bind(host: self.host, port: self.port)
    server.map {
      $0.channel.localAddress
    }.whenSuccess { address in
      logger.debug("gRPC Server started on port \(address!.port!)", metadata: nil)
    }

    self.server = try server.wait()
  }


  public var onShutdown: EventLoopFuture<Void> {
    return server!.channel.closeFuture
  }



  public func shutdown() {
    try! self.server!.close().wait()
  }


}
