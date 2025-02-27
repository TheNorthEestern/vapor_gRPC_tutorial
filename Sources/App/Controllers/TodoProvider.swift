//
//  TodoProvider.swift
//  learning_grpc
//
//  Created by Kacy James on 2/26/25.
//

import Foundation
@preconcurrency import GRPC
import Vapor
import Fluent

class TodoProvider: Todos_TodoServiceProvider {
  var interceptors: (any Todos_TodoServiceServerInterceptorFactoryProtocol)?
  var app: Application

  init(_ app: Application) {
    self.app = app
  }

  func fetchTodos(request: Todos_Empty, context: any StatusOnlyCallContext) -> EventLoopFuture<Todos_TodoList> {
    Todo.query(on: app.db(.psql)).all().map { todos in
      var listToReturn = Todos_TodoList()
      for td in todos {
        listToReturn.todos.append(Todos_Todo(td))
      }

      return listToReturn
    }
  }

  func createTodo(request: Todos_Todo, context: any StatusOnlyCallContext) -> EventLoopFuture<Todos_Todo> {
    let todo = Todo(request)
    return todo.save(on: app.db(.psql)).map { Todos_Todo(todo) }
  }

  func deleteTodo(request: Todos_TodoID, context: any StatusOnlyCallContext) -> EventLoopFuture<Todos_Empty> {
    guard let uuid = UUID(uuidString: request.todoID) else {
      return context.eventLoop.makeFailedFuture(GRPCStatus(code: .invalidArgument, message: "Invalid TodoID"))
    }

    return Todo.find(uuid, on: app.db(.psql)).unwrap(or: Abort(.notFound)).flatMap { [self] todo in
        todo.delete(on: app.db(.psql))
          .transform(to: context.eventLoop.makeSucceededFuture(Todos_Empty()))
      }
  }
}
