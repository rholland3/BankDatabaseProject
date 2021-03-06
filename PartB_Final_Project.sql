USE [master]
GO
/****** Object:  Database [Bank]    Script Date: 1/20/2019 2:05:16 PM ******/
CREATE DATABASE [Bank]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'Bank', FILENAME = N'c:\Program Files\Microsoft SQL Server\MSSQL11.SQLEXPRESS\MSSQL\DATA\Bank.mdf' , SIZE = 3136KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'Bank_log', FILENAME = N'c:\Program Files\Microsoft SQL Server\MSSQL11.SQLEXPRESS\MSSQL\DATA\Bank_log.ldf' , SIZE = 832KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
ALTER DATABASE [Bank] SET COMPATIBILITY_LEVEL = 110
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [Bank].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [Bank] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [Bank] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [Bank] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [Bank] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [Bank] SET ARITHABORT OFF 
GO
ALTER DATABASE [Bank] SET AUTO_CLOSE ON 
GO
ALTER DATABASE [Bank] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [Bank] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [Bank] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [Bank] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [Bank] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [Bank] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [Bank] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [Bank] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [Bank] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [Bank] SET  ENABLE_BROKER 
GO
ALTER DATABASE [Bank] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [Bank] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [Bank] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [Bank] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [Bank] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [Bank] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [Bank] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [Bank] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [Bank] SET  MULTI_USER 
GO
ALTER DATABASE [Bank] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [Bank] SET DB_CHAINING OFF 
GO
ALTER DATABASE [Bank] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [Bank] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
USE [Bank]
GO
/****** Object:  StoredProcedure [dbo].[AddNewCustToAccount]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AddNewCustToAccount] 
	-- Add the parameters for the stored procedure here
	--need the customer info
	@ssn char(11),
	@dob date,
	@driversLicenseNum varchar(45) = null, --can be null...
	@TelNum varchar(20), 
	@CellNum varchar(20) = null, --but this can be null so maybe it should be last...?
	@Firstname varchar(45),
	@LastName varchar(45),
	@MiddleInitial varchar(45)=null, --this cud also be null...
	--new address also
	@Street varchar(45),
	@City varchar(45),
	@State varchar(45),
	@Zip varchar(45),
	--acount info
	@AccountNum char(15)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	begin transaction
		begin try

		declare @addressID int

			--check if this is a new address or it is already in our database
			if exists(select streetAddress, city, state, zip from address where
					StreetAddress = @Street and City = @City and State = @State and Zip = @Zip)
				begin
					select @addressID = addressID from Address where
					StreetAddress = @Street and City = @City and State = @State and Zip = @Zip
				end 

			else--add the address to the address table and get its ID
			begin
				insert into Address(StreetAddress, City, State, Zip)
				values(@Street, @City, @State, @Zip)
				set @addressID = SCOPE_IDENTITY()  --get the last inserted id
			end

			--then add the customer to Customer table
			--the parameters that were able to be null can just be inserted as such, since the table allows it
			insert into customer (SSN, DOB, DriversLicenseNum, TelNum, CellNum, FirstName, LastName, MiddleInitial, AddressID)
			values(@ssn, @dob, @driversLicenseNum, @TelNum, @CellNum, @Firstname, @LastName, @MiddleInitial, @addressID)
			declare @customerID int
			set @customerID = scope_identity() --so we can use this to record whose account this is

			--then add the combination to the customer_accounts table
			insert into customer_accounts (customerID, accountNum) values(@customerID, @accountNum)

			--all went well
			commit transaction
			return 0;
		end try
		begin catch
			-- throw the error further
		   rollback transaction --cancel out the transaction
		   declare @errCode int,
		           @errMessage varchar (200),
				   @errSeverity int
				   select @errCode = ERROR_NUMBER(),
				         @errMessage = ERROR_MESSAGE(),
						 @errSeverity = ERROR_SEVERITY();
						 --raiserror (@errmessage, @errSeverity, @errState)
						 --throw must have numbers 50000 or more
           throw 50001, @errMessage, @errSeverity --throw error to calling process
         return 1;    --error condition occurred
		end catch
END




GO
/****** Object:  StoredProcedure [dbo].[CheckWithdrawal]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create procedure [dbo].[CheckWithdrawal]
	@accountNum char(15),    --account the check belongs to
	@amount decimal(18,2),    --amount on check
	@checkNum int, --check number
	@dateOnCheck date
as
BEGIN 
	set NOCOUNT ON --set number of row affected to no count
	
		begin transaction
			--now process the transaction
			begin try
				--insert into the transactions table
				insert into transactions (accountnum, transactiontype, amount, memo)
				values(@accountnum, 9, @amount, concat('CheckNum: ', @checknum))	--checkwithdrawal is type id 9

				declare @transactionid int
				set @transactionid = SCOPE_IDENTITY()

				insert into checks (transactionID, checkNum, accountnum, dateonCheck, amount) 
				values (@transactionid, @checknum, @accountnum, @dateoncheck, @amount)

		commit 
		return 0;
				end try
				begin catch
						rollback transaction;
						throw
						return -1;
				end catch

		END


GO
/****** Object:  StoredProcedure [dbo].[depositCheck]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[depositCheck]
	@accountNum char(15),
	@amount decimal(18,2),
	@memo varchar(45),
	@checkStatus bit
as
	begin
	begin transaction
		begin try
			
				--insert into the transaction table
					insert into transactions(accountNum, amount, memo, transactionType)
					values(@accountNum, @amount, @memo, 3) --3 is the id of a check transaction type
				--insert status into the check transaction table where the ids match
					--get the most recent id		
					declare @transactionID int = (select IDENT_CURRENT('transactions'))
				insert into CheckTransaction values(@transactionid, @checkStatus)
			commit
			return 0;
		end try

		begin catch
		      -- throw the error further
		   rollback transaction --cancel out the transaction
		   declare @errCode int,
		           @errMessage varchar (200),
				   @errSeverity int
				   select @errCode = ERROR_NUMBER(),
				         @errMessage = ERROR_MESSAGE(),
						 @errSeverity = ERROR_SEVERITY();
						 --raiserror (@errmessage, @errSeverity, @errState)
						 --throw must have numbers 50000 or more
           throw 50007, @errMessage, @errSeverity --throw error to calling process
         return 1;    --error condition occurred
		end catch
	end



GO
/****** Object:  StoredProcedure [dbo].[OpenAccountExistingCust]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[OpenAccountExistingCust]
	@customerID int,
	--bank account info
	@accountNum char(15),
	@accounttype int,
	--date opened will be today's date
	@initialbalance decimal(18,2), --this will be current balance also
	--if theres a separate address for the account it will be here as well
	--otherwise it will default to the customer's address
	@acctStreet varchar(45) = null,
	@acctCity varchar(45) = null,
	@acctState varchar(45) = null,
	@acctZip varchar(45) = null
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	begin try
		begin transaction
		
			declare @addressID int

			--open the account
				--check if the account has a new address or not
			if(@acctStreet is not null and @acctCity is not null and @acctState is not null and @acctZip is not null)
				 begin
					--check if this is a new address or it is already in our database
					if exists(select streetAddress, city, state, zip from address where
					StreetAddress = @acctStreet and City = @acctCity and State = @acctState and Zip = @acctZip)
						begin
							select @addressID = addressID from Address where
							StreetAddress = @acctStreet and City = @acctCity and State = @acctState and Zip = @acctZip
						end 
					else--add the address to the address table and get its ID
				begin
					insert into address (streetaddress,city,state,zip ) values(@acctStreet, @acctCity, @acctState, @acctZip)
					set @addressID = Scope_identity()
				end
			end
				else
				 begin
					select @addressID = addressID from customer where customerid = @customerID  
				 end
				
			--insert into the account, using addressID, regardless of where it was initialized
			insert into BankAccount (AccountNum, accountType, InitialBalance, CurrentBalance, AddressID)
			values (@accountNum, @accountType, @initialBalance, @initialBalance, @addressID) --initial balance is the current balance for a new account
			
			--then add the combination to the customer_accounts table
			insert into customer_accounts (customerID, accountNum) values(@customerID, @accountNum)

			--all went well
			commit transaction
			return 1;

		end try
		begin catch
			-- throw the error further
		   rollback transaction --cancel out the transaction
		   declare @errCode int,
		           @errMessage varchar (200),
				   @errSeverity int
				   select @errCode = ERROR_NUMBER(),
				         @errMessage = ERROR_MESSAGE(),
						 @errSeverity = ERROR_SEVERITY();
						 --raiserror (@errmessage, @errSeverity, @errState)
						 --throw must have numbers 50000 or more
           throw 50006, @errMessage, @errSeverity --throw error to calling process
         return 1;    --error condition occurred
		end catch


END




GO
/****** Object:  StoredProcedure [dbo].[OpenAccountNewCust]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[OpenAccountNewCust]
	--need the customer info
	@ssn varchar(11),
	@dob date,
	@driversLicenseNum varchar(45) = null, --can be null...
	@TelNum varchar(20), 
	@CellNum varchar(20) = null, --but this can be null so maybe it should be last...?
	@Firstname varchar(45),
	@LastName varchar(45),
	@MiddleInitial varchar(45)=null, --this cud also be null...
	--new address also
	@Street varchar(45),
	@City varchar(45),
	@State varchar(45),
	@Zip varchar(45),
	--bank account info
	@accountNum char(15),
	@accounttype int,
	--date opened will be today's date
	@initialbalance decimal(18,2), --this will be current balance also
	--if theres a separate address for the account it will be here as well
	--otherwise it will default to the customer address above
	@acctStreet varchar(45) = null,
	@acctCity varchar(45) = null,
	@acctState varchar(45) = null,
	@acctZip varchar(45) = null

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		begin try
			begin transaction
		declare @addressID int

			--first add the address to the address table and get its ID
			--check if this is a new address or it is already in our database
			if exists(select streetAddress, city, state, zip from address where
					StreetAddress = @Street and City = @City and State = @State and Zip = @Zip)
				begin
					select @addressID = addressID from Address where
					StreetAddress = @Street and City = @City and State = @State and Zip = @Zip
				end 

			else--add the address to the address table and get its ID
			begin
				insert into Address(StreetAddress, City, State, Zip)
				values(@Street, @City, @State, @Zip)
				set @addressID = SCOPE_IDENTITY()  --get the last inserted id
			end
			
			--then add the customer to Customer table
			--the parameters that were able to be null can just be inserted as such, since the table allows it
			insert into customer (SSN, DOB, DriversLicenseNum, TelNum, CellNum, FirstName, LastName, MiddleInitial, AddressID)
			values(@ssn, @dob, @driversLicenseNum, @TelNum, @CellNum, @Firstname, @LastName, @MiddleInitial, @addressID)
			declare @customerID int
			set @customerID = scope_identity() --so we can use this to record whose account this is

			--then open the account
				--check if the account has a new address or not
				if(@acctStreet is not null and @acctCity is not null and @acctState is not null and @acctZip is not null)
				 begin
				  	if exists(select streetAddress, city, state, zip from address where
						StreetAddress = @acctStreet and City = @acctCity and State = @acctState and Zip = @acctZip)
					begin
						select @addressID = addressID from Address where
						StreetAddress = @acctStreet and City = @acctCity and State = @acctState and Zip = @acctZip
					end 

					else--add the address to the address table and get its ID
						begin
							insert into Address(StreetAddress, City, State, Zip)
							values(@acctStreet, @acctCity, @acctState, @acctZip)
							set @addressID = SCOPE_IDENTITY()  --get the last inserted id
						end
				 end
				
			--insert into the account, using addressID, regardless of where it was initialized
			-- (either earlier with the customer info or just now for a separate address)
			insert into BankAccount (AccountNum, accountType, InitialBalance, CurrentBalance, AddressID)
			values (@accountNum, @accountType, @initialBalance, @initialBalance, @addressID) --initial balance is the current balance for a new account
			
			--then add the combination to the customer_accounts table
			insert into customer_accounts (customerID, accountNum) values(@customerID, @accountNum)

			--all went well
			commit transaction
			return 0;
		end try
		begin catch
			-- throw the error further
		   rollback transaction --cancel out the transaction
		   declare @errCode int,
		           @errMessage varchar (200),
				   @errSeverity int
				   select @errCode = ERROR_NUMBER(),
				         @errMessage = ERROR_MESSAGE(),
						 @errSeverity = ERROR_SEVERITY();
						 --raiserror (@errmessage, @errSeverity, @errState)
						 --throw must have numbers 50000 or more
           throw 50005, @errMessage, @errSeverity --throw error to calling process
         return 1;    --error condition occurred
		end catch
	
END




GO
/****** Object:  StoredProcedure [dbo].[transferMoney]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[transferMoney]
	@accountNumTo char(15),
	@accountNumFrom char(15),
	@amount decimal(18,2),
	@memo varchar(45) = null
as
	begin
		begin try
			begin transaction
				--insert into the transaction table the transfer From
					insert into transactions(accountNum, amount, memo, transactionType)
					values(@accountNumFrom, @amount, @memo, 5) --5 is the id of a transferFrom type
				--insert status into the transfer table where the ids match
					--get the most recent id		
					declare @transactionID int = (select IDENT_CURRENT('transactions'))
				insert into Transfers values(@transactionid, @accountNumTo)
				--create transaction to add the money to the account
				insert into transactions(accountNum, amount, memo, transactionType)
					values(@accountNumTo, @amount, @memo, 6) --5 is the id of a transferTo type
			commit
			return 0;
		end try

		begin catch
		      -- throw the error further
		   rollback transaction --cancel out the transaction
		   declare @errCode int,
		           @errMessage varchar (200),
				   @errSeverity int
				   select @errCode = ERROR_NUMBER(),
				         @errMessage = ERROR_MESSAGE(),
						 @errSeverity = ERROR_SEVERITY();
						 --raiserror (@errmessage, @errSeverity, @errState)
						 --throw must have numbers 50000 or more
           throw 50004, @errMessage, @errSeverity --throw error to calling process
         return 1;    --error condition occurred
		end catch
	end



GO
/****** Object:  Table [dbo].[AccountTypes]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[AccountTypes](
	[TypeID] [int] IDENTITY(1,1) NOT NULL,
	[Description] [varchar](45) NOT NULL,
	[InterestRateID] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Address]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Address](
	[AddressId] [int] IDENTITY(1,1) NOT NULL,
	[StreetAddress] [varchar](45) NOT NULL,
	[City] [varchar](45) NOT NULL,
	[State] [varchar](45) NOT NULL,
	[Zip] [varchar](45) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[AddressId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[BankAccount]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[BankAccount](
	[AccountNum] [char](15) NOT NULL,
	[AccountType] [int] NOT NULL,
	[DateOpened] [date] NOT NULL,
	[InitialBalance] [decimal](18, 2) NOT NULL,
	[CurrentBalance] [decimal](18, 2) NOT NULL,
	[AddressID] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[AccountNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Checks]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Checks](
	[transactionID] [int] NOT NULL,
	[CheckNum] [int] NOT NULL,
	[AccountNum] [char](15) NOT NULL,
	[DateOnCheck] [date] NOT NULL,
	[Amount] [decimal](18, 2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[CheckNum] ASC,
	[AccountNum] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[CheckTransaction]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CheckTransaction](
	[TransactionID] [int] NOT NULL,
	[checkStatus] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TransactionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Customer]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Customer](
	[CustomerID] [int] IDENTITY(1,1) NOT NULL,
	[SSN] [varchar](11) NOT NULL,
	[DOB] [date] NOT NULL,
	[DriversLicenseNum] [varchar](45) NULL,
	[TelNum] [varchar](20) NOT NULL,
	[CellNum] [varchar](20) NULL,
	[FirstName] [varchar](45) NOT NULL,
	[LastName] [varchar](45) NOT NULL,
	[MiddleInitial] [varchar](3) NULL,
	[AddressID] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Customer_Accounts]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Customer_Accounts](
	[AccountNum] [char](15) NOT NULL,
	[CustomerID] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[AccountNum] ASC,
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Fees]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Fees](
	[FeeID] [int] NOT NULL,
	[Description] [varchar](45) NOT NULL,
	[Amount] [decimal](18, 2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[FeeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[FeeTransaction]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[FeeTransaction](
	[TransactionID] [int] NOT NULL,
	[FeeID] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TransactionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Interest_Rates]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Interest_Rates](
	[RateID] [int] IDENTITY(1,1) NOT NULL,
	[Rate] [decimal](18, 3) NOT NULL,
	[Description] [varchar](45) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[RateID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Interest_Rates_History]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Interest_Rates_History](
	[RateID] [int] NOT NULL,
	[Date] [date] NOT NULL,
	[Rate_Amount] [decimal](18, 3) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[RateID] ASC,
	[Date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PendingFees]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PendingFees](
	[pendingFeeId] [int] IDENTITY(1,1) NOT NULL,
	[feeID] [int] NOT NULL,
	[accountNum] [char](15) NOT NULL,
	[date] [date] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[pendingFeeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Transactions]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Transactions](
	[TransactionID] [int] IDENTITY(1,1) NOT NULL,
	[AccountNum] [char](15) NOT NULL,
	[TransactionType] [int] NOT NULL,
	[Date] [date] NOT NULL,
	[Amount] [decimal](18, 2) NOT NULL,
	[Memo] [varchar](45) NULL,
PRIMARY KEY CLUSTERED 
(
	[TransactionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TransactionType]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TransactionType](
	[TransactionTypeID] [int] IDENTITY(1,1) NOT NULL,
	[Description] [varchar](45) NOT NULL,
	[add/sub] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TransactionTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Transfers]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Transfers](
	[TransactionID] [int] NOT NULL,
	[TransferToAccountNum] [char](15) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TransactionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
SET IDENTITY_INSERT [dbo].[AccountTypes] ON 

INSERT [dbo].[AccountTypes] ([TypeID], [Description], [InterestRateID]) VALUES (1, N'Savings Account', 2)
INSERT [dbo].[AccountTypes] ([TypeID], [Description], [InterestRateID]) VALUES (2, N'CD Account', 4)
INSERT [dbo].[AccountTypes] ([TypeID], [Description], [InterestRateID]) VALUES (3, N'Checking Account', 5)
INSERT [dbo].[AccountTypes] ([TypeID], [Description], [InterestRateID]) VALUES (4, N'Checking Plus Account', 3)
INSERT [dbo].[AccountTypes] ([TypeID], [Description], [InterestRateID]) VALUES (5, N'Custody Account', 2)
SET IDENTITY_INSERT [dbo].[AccountTypes] OFF
SET IDENTITY_INSERT [dbo].[Address] ON 

INSERT [dbo].[Address] ([AddressId], [StreetAddress], [City], [State], [Zip]) VALUES (1, N'123 Main St', N'Spring Valley', N'New York', N'10977')
INSERT [dbo].[Address] ([AddressId], [StreetAddress], [City], [State], [Zip]) VALUES (2, N'15 N. Main St', N'Monsey', N'New York', N'10952')
INSERT [dbo].[Address] ([AddressId], [StreetAddress], [City], [State], [Zip]) VALUES (3, N'75 First St', N'Brooklyn', N'New York', N'11230')
INSERT [dbo].[Address] ([AddressId], [StreetAddress], [City], [State], [Zip]) VALUES (7, N'741 S. Main', N'Havestraw', N'New York', N'12354')
SET IDENTITY_INSERT [dbo].[Address] OFF
INSERT [dbo].[BankAccount] ([AccountNum], [AccountType], [DateOpened], [InitialBalance], [CurrentBalance], [AddressID]) VALUES (N'123456789123456', 1, CAST(0x2F3F0B00 AS Date), CAST(5789.00 AS Decimal(18, 2)), CAST(6.00 AS Decimal(18, 2)), 1)
INSERT [dbo].[BankAccount] ([AccountNum], [AccountType], [DateOpened], [InitialBalance], [CurrentBalance], [AddressID]) VALUES (N'123698745214874', 2, CAST(0x303F0B00 AS Date), CAST(9875.00 AS Decimal(18, 2)), CAST(9875.00 AS Decimal(18, 2)), 1)
INSERT [dbo].[BankAccount] ([AccountNum], [AccountType], [DateOpened], [InitialBalance], [CurrentBalance], [AddressID]) VALUES (N'456789123852   ', 1, CAST(0x303F0B00 AS Date), CAST(17587.00 AS Decimal(18, 2)), CAST(16799.00 AS Decimal(18, 2)), 2)
INSERT [dbo].[BankAccount] ([AccountNum], [AccountType], [DateOpened], [InitialBalance], [CurrentBalance], [AddressID]) VALUES (N'741963852123   ', 1, CAST(0x303F0B00 AS Date), CAST(1700.00 AS Decimal(18, 2)), CAST(30.00 AS Decimal(18, 2)), 1)
INSERT [dbo].[BankAccount] ([AccountNum], [AccountType], [DateOpened], [InitialBalance], [CurrentBalance], [AddressID]) VALUES (N'789654123698124', 3, CAST(0x303F0B00 AS Date), CAST(4786.87 AS Decimal(18, 2)), CAST(4796.87 AS Decimal(18, 2)), 7)
INSERT [dbo].[Checks] ([transactionID], [CheckNum], [AccountNum], [DateOnCheck], [Amount]) VALUES (64, 123, N'456789123852   ', CAST(0x363F0B00 AS Date), CAST(500.00 AS Decimal(18, 2)))
INSERT [dbo].[Checks] ([transactionID], [CheckNum], [AccountNum], [DateOnCheck], [Amount]) VALUES (65, 124, N'456789123852   ', CAST(0x363F0B00 AS Date), CAST(50.00 AS Decimal(18, 2)))
INSERT [dbo].[Checks] ([transactionID], [CheckNum], [AccountNum], [DateOnCheck], [Amount]) VALUES (66, 125, N'456789123852   ', CAST(0x233F0B00 AS Date), CAST(25.00 AS Decimal(18, 2)))
INSERT [dbo].[Checks] ([transactionID], [CheckNum], [AccountNum], [DateOnCheck], [Amount]) VALUES (67, 126, N'456789123852   ', CAST(0x313F0B00 AS Date), CAST(18.00 AS Decimal(18, 2)))
INSERT [dbo].[Checks] ([transactionID], [CheckNum], [AccountNum], [DateOnCheck], [Amount]) VALUES (68, 127, N'456789123852   ', CAST(0xD53E0B00 AS Date), CAST(180.00 AS Decimal(18, 2)))
INSERT [dbo].[CheckTransaction] ([TransactionID], [checkStatus]) VALUES (13, 1)
INSERT [dbo].[CheckTransaction] ([TransactionID], [checkStatus]) VALUES (38, 1)
INSERT [dbo].[CheckTransaction] ([TransactionID], [checkStatus]) VALUES (46, 1)
INSERT [dbo].[CheckTransaction] ([TransactionID], [checkStatus]) VALUES (55, 1)
INSERT [dbo].[CheckTransaction] ([TransactionID], [checkStatus]) VALUES (59, 1)
SET IDENTITY_INSERT [dbo].[Customer] ON 

INSERT [dbo].[Customer] ([CustomerID], [SSN], [DOB], [DriversLicenseNum], [TelNum], [CellNum], [FirstName], [LastName], [MiddleInitial], [AddressID]) VALUES (1, N'123-45-6789', CAST(0xC3150B00 AS Date), NULL, N'845-362-1234', NULL, N'Esther', N'Frank', NULL, 1)
INSERT [dbo].[Customer] ([CustomerID], [SSN], [DOB], [DriversLicenseNum], [TelNum], [CellNum], [FirstName], [LastName], [MiddleInitial], [AddressID]) VALUES (4, N'123-56-4789', CAST(0x9E180B00 AS Date), NULL, N'845-362-1478', NULL, N'Daniel', N'Frank', NULL, 1)
INSERT [dbo].[Customer] ([CustomerID], [SSN], [DOB], [DriversLicenseNum], [TelNum], [CellNum], [FirstName], [LastName], [MiddleInitial], [AddressID]) VALUES (5, N'147-85-2369', CAST(0x14120B00 AS Date), NULL, N'845-367-5417', NULL, N'Tova', N'Schwartz', NULL, 2)
INSERT [dbo].[Customer] ([CustomerID], [SSN], [DOB], [DriversLicenseNum], [TelNum], [CellNum], [FirstName], [LastName], [MiddleInitial], [AddressID]) VALUES (6, N'587-74-9874', CAST(0x9F110B00 AS Date), N'123456789123', N'845-214-5748', NULL, N'Samuel', N'Cohen', N'M', 3)
INSERT [dbo].[Customer] ([CustomerID], [SSN], [DOB], [DriversLicenseNum], [TelNum], [CellNum], [FirstName], [LastName], [MiddleInitial], [AddressID]) VALUES (7, N'741-85-2369', CAST(0xBD240B00 AS Date), NULL, N'963-741-8521', NULL, N'David', N'Max', NULL, 1)
SET IDENTITY_INSERT [dbo].[Customer] OFF
INSERT [dbo].[Customer_Accounts] ([AccountNum], [CustomerID]) VALUES (N'123456789123456', 1)
INSERT [dbo].[Customer_Accounts] ([AccountNum], [CustomerID]) VALUES (N'123456789123456', 4)
INSERT [dbo].[Customer_Accounts] ([AccountNum], [CustomerID]) VALUES (N'123698745214874', 1)
INSERT [dbo].[Customer_Accounts] ([AccountNum], [CustomerID]) VALUES (N'456789123852   ', 5)
INSERT [dbo].[Customer_Accounts] ([AccountNum], [CustomerID]) VALUES (N'456789123852   ', 6)
INSERT [dbo].[Customer_Accounts] ([AccountNum], [CustomerID]) VALUES (N'741963852123   ', 7)
INSERT [dbo].[Customer_Accounts] ([AccountNum], [CustomerID]) VALUES (N'789654123698124', 4)
INSERT [dbo].[Fees] ([FeeID], [Description], [Amount]) VALUES (1, N'BouncedCheck', CAST(15.00 AS Decimal(18, 2)))
INSERT [dbo].[Fees] ([FeeID], [Description], [Amount]) VALUES (2, N'Monthly Overdraft', CAST(10.00 AS Decimal(18, 2)))
INSERT [dbo].[Fees] ([FeeID], [Description], [Amount]) VALUES (3, N'Foreign Transaction Fee', CAST(5.00 AS Decimal(18, 2)))
INSERT [dbo].[Fees] ([FeeID], [Description], [Amount]) VALUES (4, N'ATM Fee', CAST(3.00 AS Decimal(18, 2)))
INSERT [dbo].[Fees] ([FeeID], [Description], [Amount]) VALUES (5, N'Lost Card Fee', CAST(50.00 AS Decimal(18, 2)))
INSERT [dbo].[FeeTransaction] ([TransactionID], [FeeID]) VALUES (26, 1)
INSERT [dbo].[FeeTransaction] ([TransactionID], [FeeID]) VALUES (39, 1)
INSERT [dbo].[FeeTransaction] ([TransactionID], [FeeID]) VALUES (49, 1)
INSERT [dbo].[FeeTransaction] ([TransactionID], [FeeID]) VALUES (57, 1)
INSERT [dbo].[FeeTransaction] ([TransactionID], [FeeID]) VALUES (62, 1)
SET IDENTITY_INSERT [dbo].[Interest_Rates] ON 

INSERT [dbo].[Interest_Rates] ([RateID], [Rate], [Description]) VALUES (1, CAST(0.050 AS Decimal(18, 3)), N'Introductory Rate')
INSERT [dbo].[Interest_Rates] ([RateID], [Rate], [Description]) VALUES (2, CAST(0.003 AS Decimal(18, 3)), N'Standard Rate')
INSERT [dbo].[Interest_Rates] ([RateID], [Rate], [Description]) VALUES (3, CAST(0.060 AS Decimal(18, 3)), N'VIP Rate')
INSERT [dbo].[Interest_Rates] ([RateID], [Rate], [Description]) VALUES (4, CAST(0.010 AS Decimal(18, 3)), N'Business Rate')
INSERT [dbo].[Interest_Rates] ([RateID], [Rate], [Description]) VALUES (5, CAST(0.004 AS Decimal(18, 3)), N'Average Checking Rate')
SET IDENTITY_INSERT [dbo].[Interest_Rates] OFF
INSERT [dbo].[Interest_Rates_History] ([RateID], [Date], [Rate_Amount]) VALUES (1, CAST(0x2F3F0B00 AS Date), CAST(0.050 AS Decimal(18, 3)))
INSERT [dbo].[Interest_Rates_History] ([RateID], [Date], [Rate_Amount]) VALUES (2, CAST(0x2F3F0B00 AS Date), CAST(0.003 AS Decimal(18, 3)))
INSERT [dbo].[Interest_Rates_History] ([RateID], [Date], [Rate_Amount]) VALUES (3, CAST(0x2F3F0B00 AS Date), CAST(0.060 AS Decimal(18, 3)))
INSERT [dbo].[Interest_Rates_History] ([RateID], [Date], [Rate_Amount]) VALUES (4, CAST(0x2F3F0B00 AS Date), CAST(0.010 AS Decimal(18, 3)))
INSERT [dbo].[Interest_Rates_History] ([RateID], [Date], [Rate_Amount]) VALUES (5, CAST(0x2F3F0B00 AS Date), CAST(0.004 AS Decimal(18, 3)))
SET IDENTITY_INSERT [dbo].[Transactions] ON 

INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (13, N'789654123698124', 3, CAST(0x303F0B00 AS Date), CAST(0.00 AS Decimal(18, 2)), N'Groceries')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (14, N'123456789123456', 5, CAST(0x303F0B00 AS Date), CAST(50.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (15, N'789654123698124', 6, CAST(0x303F0B00 AS Date), CAST(50.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (16, N'741963852123   ', 5, CAST(0x303F0B00 AS Date), CAST(300.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (17, N'456789123852   ', 6, CAST(0x303F0B00 AS Date), CAST(300.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (18, N'789654123698124', 5, CAST(0x303F0B00 AS Date), CAST(25.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (19, N'456789123852   ', 6, CAST(0x303F0B00 AS Date), CAST(25.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (20, N'741963852123   ', 5, CAST(0x303F0B00 AS Date), CAST(1000.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (21, N'123456789123456', 6, CAST(0x303F0B00 AS Date), CAST(1000.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (22, N'123456789123456', 5, CAST(0x303F0B00 AS Date), CAST(500.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (23, N'741963852123   ', 6, CAST(0x303F0B00 AS Date), CAST(500.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (24, N'456789123852   ', 1, CAST(0x303F0B00 AS Date), CAST(100.00 AS Decimal(18, 2)), N'Babysitting Money')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (25, N'456789123852   ', 1, CAST(0x303F0B00 AS Date), CAST(150.00 AS Decimal(18, 2)), N'Tips')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (26, N'789654123698124', 4, CAST(0x303F0B00 AS Date), CAST(15.00 AS Decimal(18, 2)), N'Bounced Check Fee')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (27, N'741963852123   ', 8, CAST(0x303F0B00 AS Date), CAST(895.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (30, N'741963852123   ', 1, CAST(0x303F0B00 AS Date), CAST(975.00 AS Decimal(18, 2)), N'paycheck week of 1/14/19')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (31, N'741963852123   ', 8, CAST(0x303F0B00 AS Date), CAST(975.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (33, N'741963852123   ', 1, CAST(0x303F0B00 AS Date), CAST(975.00 AS Decimal(18, 2)), N'paycheck week of 01/27/19')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (38, N'741963852123   ', 3, CAST(0x303F0B00 AS Date), CAST(0.00 AS Decimal(18, 2)), N'This is a bounced Check')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (39, N'741963852123   ', 4, CAST(0x303F0B00 AS Date), CAST(15.00 AS Decimal(18, 2)), N'Bounced Check Fee- transactionID: 38')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (40, N'741963852123   ', 8, CAST(0x303F0B00 AS Date), CAST(965.00 AS Decimal(18, 2)), NULL)
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (46, N'741963852123   ', 3, CAST(0x303F0B00 AS Date), CAST(0.00 AS Decimal(18, 2)), N'This is another bounced Check')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (48, N'741963852123   ', 1, CAST(0x303F0B00 AS Date), CAST(50.00 AS Decimal(18, 2)), N'Money deposited in ATM on Rt 59')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (49, N'741963852123   ', 4, CAST(0x303F0B00 AS Date), CAST(15.00 AS Decimal(18, 2)), N'Bounced Check Fee')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (50, N'741963852123   ', 8, CAST(0x303F0B00 AS Date), CAST(50.00 AS Decimal(18, 2)), N'ATM')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (52, N'741963852123   ', 1, CAST(0x303F0B00 AS Date), CAST(45.00 AS Decimal(18, 2)), N'Babysitting money')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (53, N'741963852123   ', 8, CAST(0x303F0B00 AS Date), CAST(45.00 AS Decimal(18, 2)), N'ATM withdrawal')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (55, N'741963852123   ', 3, CAST(0x303F0B00 AS Date), CAST(0.00 AS Decimal(18, 2)), N'Bounced Check')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (56, N'741963852123   ', 1, CAST(0x303F0B00 AS Date), CAST(45.00 AS Decimal(18, 2)), N'Babysitting money')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (57, N'741963852123   ', 4, CAST(0x303F0B00 AS Date), CAST(15.00 AS Decimal(18, 2)), N'Bounced Check Fee')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (58, N'123456789123456', 8, CAST(0x303F0B00 AS Date), CAST(6230.00 AS Decimal(18, 2)), N'ATM withdrawal on 1-14-19')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (59, N'123456789123456', 3, CAST(0x303F0B00 AS Date), CAST(0.00 AS Decimal(18, 2)), N'Bounced Check')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (61, N'123456789123456', 1, CAST(0x303F0B00 AS Date), CAST(12.00 AS Decimal(18, 2)), N'Babysitting money')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (62, N'123456789123456', 4, CAST(0x303F0B00 AS Date), CAST(15.00 AS Decimal(18, 2)), N'Bounced Check Fee')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (64, N'456789123852   ', 9, CAST(0x363F0B00 AS Date), CAST(500.00 AS Decimal(18, 2)), N'CheckNum: 123')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (65, N'456789123852   ', 9, CAST(0x363F0B00 AS Date), CAST(50.00 AS Decimal(18, 2)), N'CheckNum: 124')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (66, N'456789123852   ', 9, CAST(0x363F0B00 AS Date), CAST(25.00 AS Decimal(18, 2)), N'CheckNum: 125')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (67, N'456789123852   ', 9, CAST(0x363F0B00 AS Date), CAST(18.00 AS Decimal(18, 2)), N'CheckNum: 126')
INSERT [dbo].[Transactions] ([TransactionID], [AccountNum], [TransactionType], [Date], [Amount], [Memo]) VALUES (68, N'456789123852   ', 9, CAST(0x363F0B00 AS Date), CAST(180.00 AS Decimal(18, 2)), N'CheckNum: 127')
SET IDENTITY_INSERT [dbo].[Transactions] OFF
SET IDENTITY_INSERT [dbo].[TransactionType] ON 

INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (1, N'DepositAtm', 1)
INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (2, N'DepositTeller', 1)
INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (3, N'CheckDeposit', 1)
INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (4, N'fee', 0)
INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (5, N'TransferFrom', 0)
INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (6, N'TransferTo', 1)
INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (7, N'OnlinePayment', 0)
INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (8, N'Withdrawal', 0)
INSERT [dbo].[TransactionType] ([TransactionTypeID], [Description], [add/sub]) VALUES (9, N'CheckWithdrawal', 0)
SET IDENTITY_INSERT [dbo].[TransactionType] OFF
INSERT [dbo].[Transfers] ([TransactionID], [TransferToAccountNum]) VALUES (14, N'789654123698124')
INSERT [dbo].[Transfers] ([TransactionID], [TransferToAccountNum]) VALUES (16, N'456789123852   ')
INSERT [dbo].[Transfers] ([TransactionID], [TransferToAccountNum]) VALUES (18, N'456789123852   ')
INSERT [dbo].[Transfers] ([TransactionID], [TransferToAccountNum]) VALUES (20, N'123456789123456')
INSERT [dbo].[Transfers] ([TransactionID], [TransferToAccountNum]) VALUES (22, N'741963852123   ')
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ__AccountT__4EBBBAC999908B12]    Script Date: 1/20/2019 2:05:16 PM ******/
ALTER TABLE [dbo].[AccountTypes] ADD UNIQUE NONCLUSTERED 
(
	[Description] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ__Customer__CA1E8E3C9DB7806B]    Script Date: 1/20/2019 2:05:16 PM ******/
ALTER TABLE [dbo].[Customer] ADD UNIQUE NONCLUSTERED 
(
	[SSN] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ__Fees__4EBBBAC93E9D450D]    Script Date: 1/20/2019 2:05:16 PM ******/
ALTER TABLE [dbo].[Fees] ADD UNIQUE NONCLUSTERED 
(
	[Description] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ__Interest__4EBBBAC999848C8D]    Script Date: 1/20/2019 2:05:16 PM ******/
ALTER TABLE [dbo].[Interest_Rates] ADD UNIQUE NONCLUSTERED 
(
	[Description] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ__Transact__4EBBBAC9AA0CC335]    Script Date: 1/20/2019 2:05:16 PM ******/
ALTER TABLE [dbo].[TransactionType] ADD UNIQUE NONCLUSTERED 
(
	[Description] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[BankAccount] ADD  DEFAULT (getdate()) FOR [DateOpened]
GO
ALTER TABLE [dbo].[Interest_Rates_History] ADD  DEFAULT (getdate()) FOR [Date]
GO
ALTER TABLE [dbo].[PendingFees] ADD  DEFAULT (getdate()) FOR [date]
GO
ALTER TABLE [dbo].[Transactions] ADD  DEFAULT (getdate()) FOR [Date]
GO
ALTER TABLE [dbo].[AccountTypes]  WITH CHECK ADD  CONSTRAINT [fk_AccountTypes_Interest_Rates] FOREIGN KEY([InterestRateID])
REFERENCES [dbo].[Interest_Rates] ([RateID])
GO
ALTER TABLE [dbo].[AccountTypes] CHECK CONSTRAINT [fk_AccountTypes_Interest_Rates]
GO
ALTER TABLE [dbo].[BankAccount]  WITH CHECK ADD  CONSTRAINT [fk_BankAccount_Address] FOREIGN KEY([AddressID])
REFERENCES [dbo].[Address] ([AddressId])
GO
ALTER TABLE [dbo].[BankAccount] CHECK CONSTRAINT [fk_BankAccount_Address]
GO
ALTER TABLE [dbo].[BankAccount]  WITH CHECK ADD  CONSTRAINT [fk_BankAcount_AccountTypes] FOREIGN KEY([AccountType])
REFERENCES [dbo].[AccountTypes] ([TypeID])
GO
ALTER TABLE [dbo].[BankAccount] CHECK CONSTRAINT [fk_BankAcount_AccountTypes]
GO
ALTER TABLE [dbo].[Checks]  WITH CHECK ADD  CONSTRAINT [fk_Check_BankAccount] FOREIGN KEY([AccountNum])
REFERENCES [dbo].[BankAccount] ([AccountNum])
GO
ALTER TABLE [dbo].[Checks] CHECK CONSTRAINT [fk_Check_BankAccount]
GO
ALTER TABLE [dbo].[CheckTransaction]  WITH CHECK ADD  CONSTRAINT [fk_checkTransaction_Transaction] FOREIGN KEY([TransactionID])
REFERENCES [dbo].[Transactions] ([TransactionID])
GO
ALTER TABLE [dbo].[CheckTransaction] CHECK CONSTRAINT [fk_checkTransaction_Transaction]
GO
ALTER TABLE [dbo].[Customer]  WITH CHECK ADD  CONSTRAINT [fk_Customer_Address] FOREIGN KEY([AddressID])
REFERENCES [dbo].[Address] ([AddressId])
GO
ALTER TABLE [dbo].[Customer] CHECK CONSTRAINT [fk_Customer_Address]
GO
ALTER TABLE [dbo].[Customer_Accounts]  WITH CHECK ADD  CONSTRAINT [fk_accounts_customer] FOREIGN KEY([AccountNum])
REFERENCES [dbo].[BankAccount] ([AccountNum])
GO
ALTER TABLE [dbo].[Customer_Accounts] CHECK CONSTRAINT [fk_accounts_customer]
GO
ALTER TABLE [dbo].[Customer_Accounts]  WITH CHECK ADD  CONSTRAINT [fk_customer_accounts] FOREIGN KEY([CustomerID])
REFERENCES [dbo].[Customer] ([CustomerID])
GO
ALTER TABLE [dbo].[Customer_Accounts] CHECK CONSTRAINT [fk_customer_accounts]
GO
ALTER TABLE [dbo].[FeeTransaction]  WITH CHECK ADD  CONSTRAINT [fk_FeeTransaction_Fee] FOREIGN KEY([FeeID])
REFERENCES [dbo].[Fees] ([FeeID])
GO
ALTER TABLE [dbo].[FeeTransaction] CHECK CONSTRAINT [fk_FeeTransaction_Fee]
GO
ALTER TABLE [dbo].[FeeTransaction]  WITH CHECK ADD  CONSTRAINT [fk_FeeTransaction_Transactions] FOREIGN KEY([TransactionID])
REFERENCES [dbo].[Transactions] ([TransactionID])
GO
ALTER TABLE [dbo].[FeeTransaction] CHECK CONSTRAINT [fk_FeeTransaction_Transactions]
GO
ALTER TABLE [dbo].[Interest_Rates_History]  WITH CHECK ADD  CONSTRAINT [fk_Interest_Rates_History_Interest_Rates] FOREIGN KEY([RateID])
REFERENCES [dbo].[Interest_Rates] ([RateID])
GO
ALTER TABLE [dbo].[Interest_Rates_History] CHECK CONSTRAINT [fk_Interest_Rates_History_Interest_Rates]
GO
ALTER TABLE [dbo].[PendingFees]  WITH CHECK ADD  CONSTRAINT [FK_PendingFees_accountNum] FOREIGN KEY([accountNum])
REFERENCES [dbo].[BankAccount] ([AccountNum])
GO
ALTER TABLE [dbo].[PendingFees] CHECK CONSTRAINT [FK_PendingFees_accountNum]
GO
ALTER TABLE [dbo].[PendingFees]  WITH CHECK ADD  CONSTRAINT [FK_pendingFees_Fees] FOREIGN KEY([feeID])
REFERENCES [dbo].[Fees] ([FeeID])
GO
ALTER TABLE [dbo].[PendingFees] CHECK CONSTRAINT [FK_pendingFees_Fees]
GO
ALTER TABLE [dbo].[Transactions]  WITH CHECK ADD  CONSTRAINT [fk_Transactions_BankAccount] FOREIGN KEY([AccountNum])
REFERENCES [dbo].[BankAccount] ([AccountNum])
GO
ALTER TABLE [dbo].[Transactions] CHECK CONSTRAINT [fk_Transactions_BankAccount]
GO
ALTER TABLE [dbo].[Transactions]  WITH CHECK ADD  CONSTRAINT [fk_Transactions_TransactionType] FOREIGN KEY([TransactionType])
REFERENCES [dbo].[TransactionType] ([TransactionTypeID])
GO
ALTER TABLE [dbo].[Transactions] CHECK CONSTRAINT [fk_Transactions_TransactionType]
GO
ALTER TABLE [dbo].[Transfers]  WITH CHECK ADD  CONSTRAINT [fk_transfers_bankAccount] FOREIGN KEY([TransferToAccountNum])
REFERENCES [dbo].[BankAccount] ([AccountNum])
GO
ALTER TABLE [dbo].[Transfers] CHECK CONSTRAINT [fk_transfers_bankAccount]
GO
ALTER TABLE [dbo].[Transfers]  WITH CHECK ADD  CONSTRAINT [fk_Transfers_Transactions] FOREIGN KEY([TransactionID])
REFERENCES [dbo].[Transactions] ([TransactionID])
GO
ALTER TABLE [dbo].[Transfers] CHECK CONSTRAINT [fk_Transfers_Transactions]
GO
ALTER TABLE [dbo].[BankAccount]  WITH CHECK ADD  CONSTRAINT [chk_accountNum] CHECK  ((isnumeric([accountNum])=(1)))
GO
ALTER TABLE [dbo].[BankAccount] CHECK CONSTRAINT [chk_accountNum]
GO
ALTER TABLE [dbo].[BankAccount]  WITH CHECK ADD  CONSTRAINT [CHK_CurrentBalance] CHECK  (([Currentbalance]>=(0)))
GO
ALTER TABLE [dbo].[BankAccount] CHECK CONSTRAINT [CHK_CurrentBalance]
GO
ALTER TABLE [dbo].[BankAccount]  WITH CHECK ADD  CONSTRAINT [CHK_InitialBalance] CHECK  (([initialbalance]>=(0)))
GO
ALTER TABLE [dbo].[BankAccount] CHECK CONSTRAINT [CHK_InitialBalance]
GO
ALTER TABLE [dbo].[Checks]  WITH CHECK ADD  CONSTRAINT [CHK_check_amount] CHECK  (([amount]>=(0)))
GO
ALTER TABLE [dbo].[Checks] CHECK CONSTRAINT [CHK_check_amount]
GO
ALTER TABLE [dbo].[Checks]  WITH CHECK ADD  CONSTRAINT [CHK_CheckNum] CHECK  (([CheckNum]>=(0)))
GO
ALTER TABLE [dbo].[Checks] CHECK CONSTRAINT [CHK_CheckNum]
GO
ALTER TABLE [dbo].[Fees]  WITH CHECK ADD  CONSTRAINT [CHK_Fee_amount] CHECK  (([amount]>=(0)))
GO
ALTER TABLE [dbo].[Fees] CHECK CONSTRAINT [CHK_Fee_amount]
GO
ALTER TABLE [dbo].[Interest_Rates]  WITH CHECK ADD  CONSTRAINT [CHK_Rate] CHECK  (([rate]>=(0)))
GO
ALTER TABLE [dbo].[Interest_Rates] CHECK CONSTRAINT [CHK_Rate]
GO
ALTER TABLE [dbo].[Interest_Rates_History]  WITH CHECK ADD  CONSTRAINT [CHK_Rate_amount] CHECK  (([rate_amount]>=(0)))
GO
ALTER TABLE [dbo].[Interest_Rates_History] CHECK CONSTRAINT [CHK_Rate_amount]
GO
ALTER TABLE [dbo].[Transactions]  WITH CHECK ADD  CONSTRAINT [CHK_trans_amount] CHECK  (([amount]>=(0)))
GO
ALTER TABLE [dbo].[Transactions] CHECK CONSTRAINT [CHK_trans_amount]
GO
/****** Object:  Trigger [dbo].[BouncedCheckFee]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE TRIGGER [dbo].[BouncedCheckFee] 
   ON  [dbo].[CheckTransaction]
   AFTER INSERT,UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for trigger here
	declare @transactionID int
	declare	@checkbounced bit
	declare @AccountNum char(15)
	declare @feeAmount decimal(18,2)
	declare @currentBalance decimal(18,2)
	declare @Fee_transactionID int --id for the new fee transaction that will be inserted
	begin try
		select @transactionID = transactionID from inserted
	
		--check if the status is bounced
			--if checkstatus is 1 then it bounced
		select @checkBounced = checkStatus from inserted
		if @checkBounced = 1
		begin
			--update transaction amount to zero in transaction table
			update transactions
				set amount = 0 where transactionID = @transactionID
			--add feetransaction for the bounced check fee
			select @accountNum = accountnum from transactions 
			where transactionID = @transactionID
	
			select @feeAmount = amount from fees
			where feeID = 1  --Bounced Check feeID is 1 

			--transactionTypeID for Fee is 4
			
			--check to see if theres enough money to add the fee, if not it goes into the pending fees
			select @currentBalance = currentBalance from BankAccount where AccountNum = @AccountNum
			if((@currentBalance - @feeAmount) >=0)
			begin
				--sufficient funds to process fee
				insert into transactions (accountNum, transactionType, date, amount, memo)
				values(@accountNum, 4, getdate(), @feeAmount, concat('Bounced Check Fee- transactionID: ',@transactionID))
				--get transactionID
				set @fee_transactionID = SCOPE_IDENTITY()
				insert into feeTransaction (transactionId, feeID) values(@fee_transactionID, 1) --bounced check is fee type 1
			end
			else
				begin
					--make this fee a pending fee that will be processed as soon as the funds come in
					insert into pendingFees (accountNum, feeId) values(@accountNum, 1)
				end
		
		end
	end try
	begin catch
	if(@@trancount>0)
		rollback transaction;
		throw 500001, 'cannot proccess fee', 11
	end catch

END




GO
/****** Object:  Trigger [dbo].[UpdateInterestHistory]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

create trigger [dbo].[UpdateInterestHistory]
on [dbo].[Interest_Rates]
AFTER INSERT, UPDATE
as
BEGIN 
	set NOCOUNT ON --set number of row affected to no count
	
	--for an update what is deleted does not need to be saved because it was saved on an insert
	--therfore the same thing happend for both an insert and an update the newly inserted data get inserted
	declare @rate decimal(18,3)
	declare @rateid int
	begin try
		set @rate = (select rate from inserted)
		set @rateid = (select rateid from inserted)

		--the rateid will be null if this is an inserted because it is an identity field
		if(@rateID=null)
		begin 
			set @rateid =(select IDENT_CURRENT('Interest_Rates'))
		end 
		insert Interest_Rates_History (rateid, rate_amount)
		values(@rateid, @rate)
	end try
	begin catch
	if(@@trancount>0)
		rollback transaction;
	throw 500002, 'cannot Update Interest', 11
	end catch
end
		



GO
/****** Object:  Trigger [dbo].[UpdateCurrentBalance]    Script Date: 1/20/2019 2:05:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE trigger  [dbo].[UpdateCurrentBalance]
	on [dbo].[Transactions]
AFTER INSERT, DELETE, UPDATE
as
BEGIN 
	set NOCOUNT ON --set number of row affected to no count
	
	--Check the type of transaction that was executed
		declare @transType char(1) --holds the transaction type
		declare @accountNum char(15)    --account the check belongs to
		declare @amount decimal(18,2)    --amount on check
		declare @transactionTypeID int --holds type id
		declare @operator	bit	--determines wether the transaction is an add or sub

		if exists(select * from inserted)
			begin
				if exists(select * from deleted)
					begin
						--this is an update
						set @transType = 'U'
					end
				else
					begin
						--else this is an insert
						set @transType ='I'
					end
			end
		else
			begin
				--then this is a delete
				set @transType ='D'
			end
	--now process the transaction

	if(@transType='D' or @transType='U')
		begin try
			--save the deleted information
			select @accountNum = accountNum, @amount = amount, @transactionTypeID = TransactionType from deleted

			--determine whether the transaction is a sub or add to current balance
			-- 0 means sub and 1 means add
			set @operator = (select [add/sub] from TransactionType where TransactionTypeID=@transactiontypeID)

			--sub
			if (@operator=0)
			begin 
				--increase the current balance
				update BankAccount
				set currentBalance = currentBalance + @amount
				where accountNum = @accountNum
			end --end the sub
			--add
			else if (@operator=1)
			begin 			
				--decrease the current balance
				update BankAccount
				set currentBalance = currentBalance - @amount
				where accountNum = @accountNum
			end -- end the decrease balance
		end try--end the add
		begin catch
		if(@@trancount>0)
			rollback transaction;
			throw 500003, 'cannot Update Balance', 11
		end catch

	if (@transType='I' or @transType='U' )
		begin try
			--save the inserted information
			select @accountNum = accountNum, @amount = amount, @transactionTypeID = transactiontype from inserted

			--determine wether the transaction is a sub or add to current balance
			set @operator = (select [add/sub] from TransactionType where TransactionTypeID=@transactiontypeID)

			--sub
			if(@operator = 0)
			begin

				--decrease the current balance
				update BankAccount
				set currentBalance = currentBalance- @amount
				where accountNum = @accountNum				
			end --end the sub
			--add
			else if(@operator=1)
			begin
					--increase the current balance
					update BankAccount
					set currentBalance = currentBalance+ @amount
					where accountNum = @accountNum

					--check if there are any pending fees to apply the newly deposited money towards
					--if there is enough money, then add it as a transaction and remove it from the pending fee table
					declare @pendingFeeId int
					declare @currentBalance decimal(18,2)
					declare @feeId int
					declare @feeamount decimal(18,2)
					declare @fee_transactionId int

					way:
					begin
						set @currentBalance = (select currentbalance from bankaccount where accountnum = @accountNum)
						set @pendingFeeId = (select top(1) pendingFeeid from pendingFees) -- get the first one in the table
						set @feeId = (select top(1) feeId from pendingFees)
					--check the balance
						set @feeamount = (select amount from fees where feeID = @feeid)
						
						if(@currentBalance - @feeamount >=0)
						begin
							--put the fee into the transaction table
							--sufficient funds to process fee
							--4 is fee type transaction
							insert into transactions (accountNum, transactionType, date, amount, memo)
							values(@accountNum, 4, getdate(), @feeAmount, 'Bounced Check Fee')
							--need to update the balance since the trigger doesnt call itself again..
							update BankAccount
							set currentBalance = currentBalance- @feeAmount
							where accountNum = @accountNum
							--get transactionID
							set @fee_transactionID = SCOPE_IDENTITY()
							insert into feeTransaction (transactionId, feeID) values(@fee_transactionID, 1) --bounced check is fee type 1
							--and remove from the pending fees table
							delete from pendingfees where pendingfeeid = @pendingFeeId
		
						end
					end --way
					if (@pendingFeeId is not null)
						goto way; --reloop to see if there are more fees that need to be processed
					


			end --end the add
	
		end try --end the insert or update
		begin catch
			if(@@trancount>0)
			rollback transaction;
			throw 500003, 'cannot Update Balance', 11
		end catch
END



GO
USE [master]
GO
ALTER DATABASE [Bank] SET  READ_WRITE 
GO
