
CREATE TABLE comicverse.editorial (
    id_editorial INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    fecha_fundacion DATE,
    sitio_web VARCHAR(255) UNIQUE
);

CREATE TABLE comicverse.comic (
    id_comic INT IDENTITY(1,1) PRIMARY KEY,
    num_comic INT,
    titulo VARCHAR(200) NOT NULL,
    id_editorial INT NULL,
    id_autor INT NOT NULL,
    fecha_publicacion DATE
);

CREATE TABLE comicverse.autor (
    id_autor INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100),
    email VARCHAR(200)
);

CREATE TABLE comicverse.cliente (
    id_cliente INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100),
    email VARCHAR(200) UNIQUE,
);

CREATE TABLE comicverse.pedido (
    id_pedido INT IDENTITY(1,1) PRIMARY KEY,
    id_cliente INT NOT NULL,
    fecha_pedido DATE,
    fecha_entrega DATE
);

CREATE TABLE comicverse.comics_pedidos (
    id_pedido INT NOT NULL,
    id_comic INT NOT NULL,
    cantidad_comics INT,
    estado VARCHAR(50)
);

ALTER TABLE comicverse.comic
ADD CONSTRAINT FK_comic_editorial
    FOREIGN KEY (id_editorial)
    REFERENCES comicverse.editorial(id_editorial);

ALTER TABLE comicverse.comic
ADD CONSTRAINT FK_comic_autor
    FOREIGN KEY (id_autor)
    REFERENCES comicverse.autor(id_autor);

ALTER TABLE comicverse.pedido
ADD CONSTRAINT FK_pedido_cliente
    FOREIGN KEY (id_cliente)
    REFERENCES comicverse.cliente(id_cliente);

    ALTER TABLE comicverse.comics_pedidos
ADD CONSTRAINT FK_comicspedidos_pedido
    FOREIGN KEY (id_pedido)
    REFERENCES comicverse.pedido(id_pedido);

ALTER TABLE comicverse.comics_pedidos
ADD CONSTRAINT FK_comicspedidos_comic
    FOREIGN KEY (id_comic)
    REFERENCES comicverse.comic(id_comic);

ALTER TABLE comicverse.autor
ADD CONSTRAINT emailunico UNIQUE (email);

ALTER TABLE comicverse.comics_pedidos
ADD CONSTRAINT PK_comics_pedidos
PRIMARY KEY (id_pedido, id_comic);

ALTER TABLE comicverse.comic
ADD inventario INT NOT NULL DEFAULT 0;


ALTER TABLE comicverse.comics_pedidos
ALTER COLUMN cantidad_comics INT NOT NULL;

ALTER TABLE comicverse.comics_pedidos
ADD CONSTRAINT CK_cantidad_comics CHECK (cantidad_comics > 0);

ALTER TABLE comicverse.comics_pedidos
ADD CONSTRAINT DF_estado DEFAULT 'Pendiente' FOR estado;

ALTER TABLE comicverse.pedido
ALTER COLUMN fecha_pedido DATETIME NULL;

ALTER TABLE comicverse.cliente ADD fecha_creacion DATETIME NULL;

ALTER TABLE [comicverse].[comic]
ADD [precio] DECIMAL(5,2) NULL;

ALTER TABLE [comicverse].[comic]
ADD [precio] DECIMAL(5,2) NOT NULL DEFAULT 4.99;

ALTER TABLE [comicverse].[pedido]
ADD [total] DECIMAL(10,2) NULL;





CREATE TRIGGER trg_update_total_pedido
ON [comicverse].[comics_pedidos]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Actualizar el total de los pedidos afectados
    UPDATE p
    SET p.total = (
        SELECT SUM(cp.cantidad_comics * c.precio)
        FROM [comicverse].[comics_pedidos] cp
        INNER JOIN [comicverse].[comic] c ON cp.id_comic = c.id_comic
        WHERE cp.id_pedido = p.id_pedido
    )
    FROM [comicverse].[pedido] p
    WHERE p.id_pedido IN (
        SELECT DISTINCT id_pedido FROM inserted
        UNION
        SELECT DISTINCT id_pedido FROM deleted
    );
END;
GO






CREATE TRIGGER trg_check_inventario
ON comicverse.comics_pedidos
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar inventario suficiente
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN comicverse.comic c
            ON i.id_comic = c.id_comic
        WHERE i.cantidad_comics > c.inventario
    )
    BEGIN
        RAISERROR('Inventario insuficiente para este comic', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- Insertar detalle del pedido
    INSERT INTO comicverse.comics_pedidos (id_pedido, id_comic, cantidad_comics, estado)
    SELECT id_pedido, id_comic, cantidad_comics, estado
    FROM inserted;

    -- Actualizar inventario
    UPDATE c
    SET c.inventario = c.inventario - i.cantidad_comics
    FROM comicverse.comic c
    INNER JOIN inserted i
        ON c.id_comic = i.id_comic;
END;

